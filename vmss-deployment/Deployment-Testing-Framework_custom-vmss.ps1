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
    [string]$ParametersFile,
    [bool]$Complete,
    [bool]$Quiet
)

#$ResourceGroupName = (-join ((48..57) + (97..122) | Get-Random -Count 8 | % {[char]$_}))
$OUTPUT = "Deployment-Testing-Framework-OUTPUT-" + $ResourceGroupName
write-output "`n"
Start-Transcript -path $OUTPUT -append

if ($Quiet -eq $true) { }
else {
write-output "`n{{{-------------------------------------------|-/-/-/-^-\-\-\-|-------------------------------------------}}}`n"
write-output "`nOpening testing framework: Microsoft Azure Virtual Machine Scale Set (VMSS)`n"
}

write-output "`nLOCATION: $Location"
date

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
$createrg = (New-AzureRmResourceGroup -Location $Location -Name $ResourceGroupName)
if ($Complete -eq $true) { write-output $createrg }

$ENDCREATERG = (get-date -displayhint Time)

$TSCREATERG = ([datetime]"$ENDCREATERG" -[datetime]"$STARTCREATERG")
"`nThe time taken to create the Azure Resource Group '$ResourceGroupName': {0:c}" -f $TSCREATERG

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

$STARTDEPLOYMENTCREATE = (get-date -displayhint Time)
if ($Quiet -eq $true) { }
else {
write-output "`nStarting deployment from template files provided...`n"
}
$createdep = (New-AzureRmResourceGroupDeployment -TemplateFile $TemplateFile -TemplateParameterFile $ParametersFile -Name $ResourceGroupName-testframeworkdeployment -ResourceGroupName $ResourceGroupName)
if ($Complete -eq $true) { write-output $createdep }

$ENDDEPLOYMENTCREATE = (get-date -displayhint Time)

if ($Complete -eq $true) { write-output "`nCapturing details of the deployment operations:" }

$getops = ((Get-AzureRmResourceGroupDeploymentOperation -ResourceGroupName $ResourceGroupName -DeploymentName $ResourceGroupName-testframeworkdeployment).Properties | select-object provisioningoperation,duration,targetresource | Format-list)
if ($Complete -eq $true) { write-output $getops }

$TSDEPLOYMENT = ([datetime]"$ENDDEPLOYMENTCREATE" -[datetime]"$STARTDEPLOYMENTCREATE")
"The time taken to complete the template deployment '$ResourceGroupName-testframeworkdeployment': {0:c}" -f $TSDEPLOYMENT

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

$vmssName = (get-azurermvmss -ResourceGroupName $ResourceGroupName).Name
$vmss = (get-azurermvmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $vmssName)
$vmss.sku.capacity = 0

$deprov = (Update-AzureRmVmss -ResourceGroupName $ResourceGroupName -Name vmss -VirtualMachineScaleSet $vmss)
if ($Complete -eq $true) { write-output $deprov }

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

write-output "`nNow deleting the Azure Resource Group created for this exercise: $ResourceGroupName..."
write-output "`nIf 'True', the Resource Group has been successfully deleted:"
}
$STARTDELETERG = (get-date -displayhint Time)

if ($Quiet -eq $true) { remove-azurermresourcegroup -resourcegroupname $ResourceGroupName -force | out-null }
else { remove-azurermresourcegroup -resourcegroupname $ResourceGroupName -force }

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