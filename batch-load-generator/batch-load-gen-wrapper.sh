#!/bin/bash

set -e

#LOG="batch-load-gen-output.log"
#exec 2>&1  

testsetup() 
{
if ! touch ./BATCH-LOAD-GEN.FILE 2&> /dev/null
then	
    echo -e "\n\nFiles will be modified in this working directory as part of the script and are critical to its operation. 

However, we cannot write here --- please move to a directory where you have write privileges, and re-run this script.\n\n" 
    exit 1
else
    rm ./BATCH-LOAD-GEN.FILE
fi

if [ ! -f azure.config ]
then 
    echo -e "No azure.config file detected in the current working directory - please ensure that the file exists and is named correctly.\n"
    exit 1
fi

if [ ! -f batch-client-job.json ]
then 
    echo -e "The Batch Client Job submission json template is not in the current working directory - please ensure that the file exists and is named correctly.\n"
    exit 1
fi

if [ ! -f batch-client-pool.json ]
then 
    echo -e "The Batch Client Pool json template is not in the current working directory - please ensure that the file exists and is named correctly.\n"
    exit 1
fi
}

help() {
    echo -e "
This script creates Azure Batch resources to enable parallel scale testing.

Such tests could include storage performance tests or saturating connection counts to a target device, resource or application.

::SYNTAX::

\t$ /path/to/batch-load-gen-wrapper.sh -j <JOB_NAME> -p <POOL_ID> -t <NUMBER_OF_TASKS> -n <URL_OF_NODE_CONFIG> -w <URL_OF_JOB_CONFIG>

\t$ /path/to/batch-load-gen-wrapper.sh \
\t-j SEQUENTIAL_READ \ \t\t# Job name
\t-p GLUSTER_FS_01 \ \t\t# Pool ID
\t-t 39 \ \t\t# Tasks
\t-n http://aka.ms/glusterfs-nodesetup.sh \t\t# Node config
\t-w http://aka.ms/glusterfs-perftest.sh \t\t# Job config

The default VM size is Standard_D1_v2. If you want to modify the size of a VM on which these tasks run (i.e. to take advantage of program-level parallelisation), utilise 
the '-s' switch and specify a valid VM type. For example:

\t$ /path/to/batch-load-gen-wrapper.sh \
\t-j SEQUENTIAL_READ \ \t\t# Job name
\t-p GLUSTER_FS_01 \ \t\t# Pool ID
\t-s Standard_F8 \ \t\t# Azure VM size <<<<
\t-t 39 \ \t\t# Tasks
\t-n http://aka.ms/glusterfs-nodesetup.sh \t\t# Node config
\t-w http://aka.ms/glusterfs-perftest.sh \t\t# Job config

\n\n"

    exit 1
}

testsetup

while getopts :j:p:t:n:w:s option
do 
case "$option"
in
    j) JOB_NAME=${OPTARG} ;;
    p) POOL_ID=${OPTARG} ;;
    t) TASK_NUM=${OPTARG} ;;
    n) NODE_CFG="${OPTARG}" ;;
    w) JOB_CFG="${OPTARG}" ;;
    s) VM_SIZE="${OPTARG}" ;;
    *) help ;;
esac
done

echo -e "\n"
read -p "Please ensure you have logged into the Azure CLI prior to running this script. Press 'Enter' to continue if so..."
echo -e "\n"

# Collecting Batch credentials from the accompanying credentials file
if cat azure.config | grep "ACCOUNT" > /dev/null
then 
    echo -e "You need to update the azure.config file to include all specific Batch account details. \n\nExiting...\n"
    exit 1
fi
BATCH_ACCT=$(cat azure.config | grep BATCH_ACCT | awk '{print $2}')
BATCH_ENDPOINT=$(cat azure.config | grep BATCH_ENDPOINT | awk '{print $2}')
BATCH_KEY=$(cat azure.config | grep BATCH_KEY | awk '{print $2}')

if cat azure.config | grep "VIRTUAL_NETWORK" > /dev/null
then 
    echo -e "You need to update the azure.config file to include all specific Azure Virtual Network details. \n\nExiting...\n"
    exit 1
fi
VNET_NAME=$(cat azure.config | grep VNET_NAME | awk '{print $2}')
VNET_SUBNET=$(cat azure.config | grep VNET_SUBNET | awk '{print $2}')
VNET_RG=$(cat azure.config | grep VNET_RG | awk '{print $2}')

SUBNET_ID=$(az network vnet subnet show --resource-group ${VNET_RG} --vnet-name ${VNET_NAME} --name ${VNET_SUBNET} -o tsv | awk '{print $3}')
if [ -z ${SUBNET_ID} ]
then
    echo -e "Variable SUBNET_ID could not be set - exiting...\n\n"
    exit 1
fi

echo -e "Operational variables set...\n"

# Pool: Check to see whether a pool of the name ${POOL_ID} exists, and if not, create it
if ! az batch pool list --account-name ${BATCH_ACCT} --account-endpoint ${BATCH_ENDPOINT} --account-key ${BATCH_KEY} | grep -i ${POOL_ID} > /dev/null
then
    echo -e "Azure Batch Pool \"${POOL_ID}\" doesn't exist - working to create this now...\n"

    cp batch-client-pool.json ${POOL_ID}-batch-client-pool.json

    sed -i "s#POOL_ID_NULL#${POOL_ID}#g" ${POOL_ID}-batch-client-pool.json
    sed -i "s#NODE_CFG_NULL#${NODE_CFG}#g" ${POOL_ID}-batch-client-pool.json
    sed -i "s#TASK_NUM_NULL#${TASK_NUM}#g" ${POOL_ID}-batch-client-pool.json
    sed -i "s#SUBNET_ID_NULL#${SUBNET_ID}#g" ${POOL_ID}-batch-client-pool.json

    if [ ! -z ${VM_SIZE} ]
    then
        sed -i "s#Standard_D1_v2#${VM_SIZE}#g" ${POOL_ID}-batch-client-pool.json
    fi

    echo -e "Pool template modified with provided definitions...\n"

    az batch pool create --account-name ${BATCH_ACCT} --account-endpoint ${BATCH_ENDPOINT} --account-key ${BATCH_KEY} --template ${POOL_ID}-batch-client-pool.json

    echo -e "Azure Batch Pool created...\n"
else
    echo -e "Azure Batch Pool \"${POOL_ID}\" exists - selecting this for use with the job...\n"
fi

sleep 30

# Job: Submission
cp batch-client-job.json ${JOB_NAME}-batch-client-job.json

TASK_NUM=$(( ${TASK_NUM} - 1 ))

sed -i "s#POOL_ID_NULL#${POOL_ID}#g" ${JOB_NAME}-batch-client-job.json
sed -i "s#JOB_NAME_NULL#${JOB_NAME}#g" ${JOB_NAME}-batch-client-job.json
sed -i "s#TASK_NUM_NULL#${TASK_NUM}#g" ${JOB_NAME}-batch-client-job.json
sed -i "s#JOB_CFG_NULL#${JOB_CFG}#g" ${JOB_NAME}-batch-client-job.json

echo -e "Job template modified with provided definitions...\n"

az batch job create --account-name ${BATCH_ACCT} --account-endpoint ${BATCH_ENDPOINT} --account-key ${BATCH_KEY} --template ${JOB_NAME}-batch-client-job.json

echo -e "Azure Batch Job created...\n\n"