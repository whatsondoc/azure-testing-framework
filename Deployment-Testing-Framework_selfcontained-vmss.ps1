Param(
[bool]$Complete,
[bool]$Quiet
)

if ( (test-path -path azuredeploy.json) -and (test-path -path azuredeploy.parameters.json) )
{
$RNDNAME = (-join ((48..57) + (97..122) | Get-Random -Count 8 | % {[char]$_}))
$OUTPUT = "Deployment-Testing-Framework-OUTPUT-" + $RNDNAME
write-output "`n"
Start-Transcript -path $OUTPUT -append -noclobber

if ($Quiet -eq $true) { }
else {
write-output "`n{{{-------------------------------------------|-/-/-/-^-\-\-\-|-------------------------------------------}}}`n"
write-output "`nOpening testing framework: Microsoft Azure Virtual Machine Scale Set (VMSS)`n"
}

$LOCATION = "northcentralus"
write-output "`nLOCATION: $Location"
date

write-output "`nOur random string for this deployment: $RNDNAME"


function create-rg {
if ($Quiet -eq $true) { }
else {
write-output "`n
###########################################
## 0%-->25%: Create Azure Resource Group ##
###########################################
"
}
$STARTCREATERG = (get-date -displayhint Time)
if ($Quiet -eq $true) { }
else {
write-output "`nCreating Azure Resource Group..."
}

$createrg = (New-AzureRmResourceGroup -Location $LOCATION -Name $RNDNAME-rg)
if ($Complete) { write-output $createrg }

$ENDCREATERG = (get-date -displayhint Time)

$TSCREATERG = ([datetime]"$ENDCREATERG" -[datetime]"$STARTCREATERG")
"`nThe time taken to create the Azure Resource Group '$RNDNAME-rg': {0:c}" -f $TSCREATERG

}

function create-deployment {
if ($Quiet -eq $true) { }
else {
write-output "`n
###########################################
## 25%-->50%: Create template deployment ##
###########################################
" 
}

# You will need the deployment templates on the local machine called 'azuredeploy.json' & '<something>.parameters.json'
# Initiating a deployment from a local set of deployment template & parameter files to the above RG:

$STARTDEPLOYMENTCREATE = (get-date -displayhint Time)
if ($Quiet -eq $true) { }
else {
write-output "`nStarting deployment from template files provided...`n"
}

$createdep = (New-AzureRmResourceGroupDeployment -TemplateFile ./azuredeploy.json -TemplateParameterFile ./azuredeploy.parameters.json -Name $RNDNAME-testframeworkdeployment -ResourceGroupName $RNDNAME-rg)
if ($Complete) { write-output $createdep }

$ENDDEPLOYMENTCREATE = (get-date -displayhint Time)

if ($Complete) { write-output "`nCapturing details of the deployment operations:" }

$getops = ((Get-AzureRmResourceGroupDeploymentOperation -ResourceGroupName $RNDNAME-rg -DeploymentName $RNDNAME-testframeworkdeployment).Properties | select-object provisioningoperation,duration,targetresource | Format-list)
if ($Complete) { write-output $getops }

$TSDEPLOYMENT = ([datetime]"$ENDDEPLOYMENTCREATE" -[datetime]"$STARTDEPLOYMENTCREATE")
"The time taken to complete the template deployment '$RNDNAME-deployment': {0:c}" -f $TSDEPLOYMENT

}


function deprovision-vmss {
if ($Quiet -eq $true) { }
else {
write-output "`n
###########################################
## 50%-->75%: Deprovision VMSS Resources ##
###########################################
" 

write-output "`nDeprovisioning the VMSS to 0 nodes..."
}
$STARTDEPROVISIONVMSS = (get-date -displayhint Time)

$vmssName = (get-azurermvmss -ResourceGroupName $RNDNAME-rg).Name
$vmss = (get-azurermvmss -ResourceGroupName $RNDNAME-rg -VMScaleSetName $vmssName)
$vmss.sku.capacity = 0

$deprov = (Update-AzureRmVmss -ResourceGroupName $RNDNAME-rg -Name vmss -VirtualMachineScaleSet $vmss)
if ($Complete) { write-output $deprov }

$ENDDEPROVISIONVMSS = (get-date -displayhint Time)
if ($Quiet -eq $true) { }
else {
write-output "Deprovisioning completed: $vmssName`n" 
}

$TSDEPROVISION = ([datetime]"$ENDDEPROVISIONVMSS" -[datetime]"$STARTDEPROVISIONVMSS")
"`nThe time taken to deprovision $vmssName nodes to 0: {0:c}" -f $TSDEPROVISION

}


function delete-rg {
if ($Quiet -eq $true) { }
else {
write-output "`n
###########################################
## 75%-->100%: Deleting RG and resources ##
###########################################
" 

write-output "`nNow deleting the Azure Resource Group created for this exercise: $RNDNAME-rg..."
write-output "`nIf 'True', the Resource Group has been successfully deleted:"
}

$STARTDELETERG = (get-date -displayhint Time)

if ($Quiet -eq $true) { remove-azurermresourcegroup -resourcegroupname $RNDNAME-rg -force | out-null }
else { remove-azurermresourcegroup -resourcegroupname $RNDNAME-rg -force }

$ENDDELETERG = (get-date -displayhint Time)

$TSDELETERG = ([datetime]"$ENDDELETERG" -[datetime]"$STARTDELETERG")
"`nThe time taken to delete the Resource Group $RNDNAME-rg: {0:c}" -f $TSDELETERG

write-output "`n"

}

create-rg
create-deployment
deprovision-vmss
delete-rg

Stop-Transcript

write-output "`n"

}