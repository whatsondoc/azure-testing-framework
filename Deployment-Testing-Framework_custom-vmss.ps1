Param(
    [string]$ResourceGroupName, 
    [string]$Location,
    [Parameter()]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf})]
    [ValidatePattern( '\.json$')]
    [string]$TemplateFile,
    [Parameter()]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf})]
    [ValidatePattern( '\.parameters.json$')]
    [string]$ParametersFile
)

#$ResourceGroupName = (-join ((48..57) + (97..122) | Get-Random -Count 8 | % {[char]$_}))
$OUTPUT = "Deployment-Testing-Framework-OUTPUT-" + $ResourceGroupName
echo "`n"
Start-Transcript -path $OUTPUT -append

write-output "`n{{{-------------------------------------------|-/-/-/-^-\-\-\-|-------------------------------------------}}}`n"
write-output "`nOpening testing framework: Microsoft Azure Virtual Machine Scale Set (VMSS)`n"


function create-rg {
write-output "`n
###########################################
## 0%-->25%: Create Azure Resource Group ##
###########################################
"

$STARTCREATERG = (get-date -displayhint Time)
write-output "`nCreating Azure Resource Group..."

New-AzureRmResourceGroup -Location $Location -Name $ResourceGroupName 

$ENDCREATERG = (get-date -displayhint Time)

$TSCREATERG = ([datetime]"$ENDCREATERG" -[datetime]"$STARTCREATERG")
"`nThe time taken to create the Azure Resource Group '$ResourceGroupName': {0:c}" -f $TSCREATERG

}

function create-deployment {
write-output "`n
###########################################
## 25%-->50%: Create template deployment ##
###########################################
" 

# You will need the deployment templates on the local machine called 'azuredeploy.json' & '<something>.parameters.json'
# Initiating a deployment from a local set of deployment template & parameter files to the above RG:

$STARTDEPLOYMENTCREATE = (get-date -displayhint Time)
write-output "`nStarting deployment from template files provided...`n"

New-AzureRmResourceGroupDeployment `
-TemplateFile $TemplateFile `
-TemplateParameterFile $ParametersFile `
-Name $ResourceGroupName-testframeworkdeployment `
-ResourceGroupName $ResourceGroupName 

$ENDDEPLOYMENTCREATE = (get-date -displayhint Time)

write-output "`nCapturing details of the deployment operations:"

(Get-AzureRmResourceGroupDeploymentOperation -ResourceGroupName $ResourceGroupName -DeploymentName $ResourceGroupName-testframeworkdeployment).Properties | select-object provisioningoperation,duration,targetresource | Format-list

$TSDEPLOYMENT = ([datetime]"$ENDDEPLOYMENTCREATE" -[datetime]"$STARTDEPLOYMENTCREATE")
"The time taken to complete the template deployment '$ResourceGroupName-testframeworkdeployment': {0:c}" -f $TSDEPLOYMENT

}


function deprovision-vmss {
write-output "`n
######################################
## 50%-->75%: Deprovision Resources ##
######################################
" 

write-output "`nDeprovisioning the VMSS to 0 nodes..."
$STARTDEPROVISIONVMSS = (get-date -displayhint Time)

$vmssName = (get-azurermvmss -ResourceGroupName $ResourceGroupName).Name
$vmss = (get-azurermvmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $vmssName)
$vmss.sku.capacity = 0

Update-AzureRmVmss -ResourceGroupName $ResourceGroupName -Name vmss -VirtualMachineScaleSet $vmss | out-null

$ENDDEPROVISIONVMSS = (get-date -displayhint Time)
write-output "Deprovisioning completed: $vmssName`n" 

$TSDEPROVISION = ([datetime]"$ENDDEPROVISIONVMSS" -[datetime]"$STARTDEPROVISIONVMSS")
"`nThe time taken to deprovision $vmssName nodes to 0: {0:c}" -f $TSDEPROVISION

}


function delete-rg {
write-output "`n
##########################################################
## 75%-->100%: Deleting Resource Group and its contents ##
##########################################################
" 

write-output "`nNow deleting the Azure Resource Group created for this exercise: $ResourceGroupName..."
write-output "`nIf 'True', the Resource Group has been successfully deleted:"

$STARTDELETERG = (get-date -displayhint Time)

remove-azurermresourcegroup -resourcegroupname $ResourceGroupName -force

$ENDDELETERG = (get-date -displayhint Time)

$TSDELETERG = ([datetime]"$ENDDELETERG" -[datetime]"$STARTDELETERG")
"`nThe time taken to delete the Resource Group '$ResourceGroupName': {0:c}" -f $TSDELETERG

echo "`n"

}

create-rg
create-deployment
deprovision-vmss
delete-rg

Stop-Transcript

echo "`n"