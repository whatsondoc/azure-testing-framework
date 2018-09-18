#!/bin/bash

set -e

#LOG="batch-load-gen-output.log"
#exec 2>&1  

echo -e "\n"
read -p "Please ensure you have logged into the Azure CLI prior to running this script. Press 'Enter' to continue if so..."
echo -e "\n"

testsetup() {
if ! touch ./BATCH-LOAD-GEN.FILE 2&> /dev/null
then	
echo -e "\n\nFiles will be downloaded/created in this working directory as part of the script and are critical to its operation. 

However, we cannot write here --- please move to a directory where you have write privileges, and re-run this script.\n\n" 
exit 1
else
rm ./BATCH-LOAD-GEN.FILE
fi

if [ ! -f batch.creds ]
then echo -e "No batch.creds file detected in the current working directory - please ensure that the file exists and is named correctly.\n"
fi

if [ ! -f batch-client-job.json ]
then echo -e "The Batch Client Job submission json template is not in the current working directory - please ensure that the file exists and is named correctly.\n"
}

if [ ! -f batch-client-pool.json ]
then echo -e "The Batch Client Pool json template is not in the current working directory - please ensure that the file exists and is named correctly.\n"
}

help() {
    echo -e "
This script creates Azure Batch resources to enable parallel scale testing.

Such tests could include storage performance tests or saturating connection counts to a target device, resource or application.

::SYNTAX::

    $ /path/to/batch-load-gen-wrapper.sh --job-id <JOB_NAME> --pool-id <POOL_ID> --tasks <NUMBER_OF_TASKS> --node-cfg <URL_OF_NODE_NODE_CFG> --job-cfg <URL_OF_JOB_NODE_CFG>
    $ /path/to/batch-load-gen-wrapper.sh -j <JOB_NAME> -p <POOL_ID> -t <NUMBER_OF_TASKS> -n <URL_OF_NODE_NODE_CFG> -w <URL_OF_JOB_NODE_CFG>

    $ /path/to/batch-load-gen-wrapper.sh \
    --job SEQUENTIAL_READ \
    --pool GLUSTER_FS_01 \
    --tasks 39 \
    --nodecfg http://aka.ms/glusterfs-nodesetup.sh
    --jobcfg http://aka.ms/glusterfs-perftest.sh
\n\n"

    exit 1
}

testperms

while getopts :j:p:t:n:w: option
do 
case "$option"
in
    j) JOB_NAME=${OPTARG} ;;
    p) POOL_ID=${OPTARG} ;;
    t) TASK_NUM=${OPTARG} ;;
    n) NODE_CFG="${OPTARG}" ;;
    w) JOB_CFG="${OPTARG}" ;;
    *) help ;;
esac
done

# Collecting Batch credentials from the accompanying credentials file
BATCH_ACCT=$(cat batch.creds | grep BATCH_ACCT | awk '{print $2}')
BATCH_ENDPOINT=$(cat batch.creds | grep BATCH_ENDPOINT | awk '{print $2}')
BATCH_KEY=$(cat batch.creds | grep BATCH_KEY | awk '{print $2}')

# Pool: Check to see whether a pool of the name ${POOL_ID} exists, and if not, create it
if ! az batch pool list --account-name ${BATCH_ACCT} --account-endpoint ${BATCH_ENDPOINT} --account-key ${BATCH_KEY} | grep -i ${POOL_ID} > /dev/null
then
    sed -i "s/POOL_ID_NULL/${POOL_ID}/g" batch-client-pool.json
    sed -i "s/NODE_CFG_NULL/${NODE_CFG}/g" batch-client-pool.json
    
    az batch pool create --account-name ${BATCH_ACCT} --account-endpoint ${BATCH_ENDPOINT} --account-key ${BATCH_KEY} --template batch-client-pool.json
fi

sleep 30

# Job: Submission
sed -i "s/POOL_ID_NULL/${POOL_ID}/g" batch-client-job.json
sed -i "s/JOB_NAME_NULL/${JOB_NAME}/g" batch-client-job.json
sed -i "s/TASK_NUM_NULL/${TASK_NUM}/g" batch-client-job.json
sed -i "s/JOB_CFG_NULL/${JOB_CFG}/g" batch-client-job.json

az batch job create --account-name ${BATCH_ACCT} --account-endpoint ${BATCH_ENDPOINT} --account-key ${BATCH_KEY} --template batch-client-job.json