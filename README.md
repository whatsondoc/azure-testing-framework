# Azure Testing Framework

Scripts for testing Azure services or deployments. The process, in short, is to create a Resource Group, initiate a deployment from a template, deprovision the VMSS resources to 0, and finally delete the Resource Group.

Logging is in place throughout to capture times taken to complete the different stages.

The PowerShell scripts (.ps1) have different characteristics:

_____________________
:: selfcontained-vmss
Allows a user to just run the script without any other parameters/options. A random string will be generated and used to name a Resouce Group & template deployment.

A default location is explicitly set in the script ('northcentralus'), but can be set to any Azure region.

There is a dependency of having an azuredeploy.json and azuredeploy.parameters.json file in the working directory.

______________
:: custom-vmss
Allows a user to specify a name for the Resource Group, location (Azure region), a specific ARM template file and a specific parameters file (to accompany the ARM template).


Both scripts have optional parameters:

[bool] -Complete $true
Prints extra detail pertaining to the tasks and logs to the output file.

[bool] -Quiet $true
Suppresses output and limits to just the pertinent details (location, start time, [random string], time events).
