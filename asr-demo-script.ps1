#> This is an azure powershell script created to be execute from the azure portal Cloud Shell. 
#> The objective is to create a source environment with real data to be protected and create the target environment with the require configuration.   

$sourcerg = "asr-source"
new-azurermresourcegroup -name $sourcerg -location eastus2
New-AzureRmResourceGroupDeployment -resourcegroupname $sourcerg -templateuri https://raw.githubusercontent.com/javieriroman/azuretemplates/master/2tierlblinuxmysql-asrdemo-source.json

#> Now you have to create a automation account with run as service principal. 
#> If you have one already please check the name and the location because the next will ask you both

$targetrg = "asr-target"
new-azurermresourcegroup -name $targetrg -location westus2
New-AzureRmResourceGroupDeployment -resourcegroupname $targetrg -templateuri  https://raw.githubusercontent.com/javieriroman/azuretemplates/master/2tierlblinuxmysql-asrdemo-target.json 

#> Now go in the the recently create azure vault and in order to select the VMs that are going to be replicated/protected. 
#> Inside the vault select the replicated items tile, click on the + replicate on the top section.
#> Now select the type of replication in this case "Azure to Azure" and the newtork mapping for the target site.

#> After replication has been enable on all the VMs we proceed to create automation variable for the post script.
#> Please make sure that each value aligned with the current name of the resource you are defining.

New-AzureRmAutomationVariable -ResourceGroupName asr-target -AutomationAccountName asr-automation -Name myrecoveryplan-LB -Value myLB-asr -Encrypted $false
New-AzureRmAutomationVariable -ResourceGroupName asr-target -AutomationAccountName asr-automation -Name myrecoveryplan-LBRG -Value asr-target -Encrypted $false 

New-AzureRmAutomationVariable -ResourceGroupName asr-target -AutomationAccountName asr-automation -Name myrecoveryplan-NSG -Value new-nsg-asr -Encrypted $false
New-AzureRmAutomationVariable -ResourceGroupName asr-target -AutomationAccountName asr-automation -Name myrecoveryplan-NSGRG -Value asr-target -Encrypted $false 

New-AzureRmAutomationVariable -ResourceGroupName asr-target -AutomationAccountName asr-automation -Name myrecoveryplan-TM -Value asrdemoarrow -Encrypted $false
New-AzureRmAutomationVariable -ResourceGroupName asr-target -AutomationAccountName asr-automation -Name myrecoveryplan-TMRG -Value asr-source -Encrypted $false 

#> Then go the link below to download the post script i create in order to import it as runbook.

Start-BitsTransfer -source https://raw.githubusercontent.com/javieriroman/azurepowershell/master/asr-add-internaldnslabel -Destination $HOME/add-idnslabel.ps1
Import-AzureRmAutomationRunbook -AutomationAccountName asr-automation -Name postscript1 -ResourceGroupName asr-target -Type PowerShell -Path $HOME/add-idnslabel.ps1 -Published

Start-BitsTransfer -source https://raw.githubusercontent.com/javieriroman/azurepowershell/master/asr-demo-postscript.ps1 -Destination $HOME/glue-everything.ps1
Import-AzureRmAutomationRunbook -AutomationAccountName asr-automation -Name postscript2 -ResourceGroupName asr-target -Type PowerShell -Path $HOME/glue-everything.ps1 -Published

#> Go to the automation account, select runbook, select create new, put name and type "powershell"
#> Once create select the created runbook and select edit, copy the content from the link above, 
#> then select save and publish. Now you can use it on the recovery plan.  

#> Last step is to create a recovery plan, base on this exersice the name should be "myrecoveryplan"
#> Go into the recovery plan and hit customize to define the recovery process. 
#> You should have 2 group members, the first one for the mysql server with a post action name postscript1 
#> and the second one for the web VMs with a post action name postscript2. 
#> After this you are ready to exectute a test failover.
