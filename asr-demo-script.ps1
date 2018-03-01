$sourcerg = "asr-source"
new-azurermresourcegroup -name $sourcerg -location eastus2
New-AzureRmResourceGroupDeployment -resourcegroupname $sourcerg -templateuri https://raw.githubusercontent.com/javieriroman/azuretemplates/master/2tierlblinuxmysql-asrdemo-source.json

#> Now you have to create a automation account with run as service principal. 
#> If you have one already please check the name and the location because the next will ask you both

$targetrg = "asr-target"
new-azurermresourcegroup -name $targetrg -location westus2
New-AzureRmResourceGroupDeployment -resourcegroupname $targetrg -templateuri  https://raw.githubusercontent.com/javieriroman/azuretemplates/master/2tierlblinuxmysql-asrdemo-target.json 

#> Now we select the VMs that are going to be replicated/protected on the portal, 
#> select the type of replication in this case "Azure to Azure" and the newtork mapping for the target site.

#> After replication has been enable on all the VMs we proceed to create automation variable for the post script

New-AzureRmAutomationVariable -ResourceGroupName asr-target -AutomationAccountName asr-automation -Name myrecoveryplan-LB -Value myLB-asr -Encrypted $false
New-AzureRmAutomationVariable -ResourceGroupName asr-target -AutomationAccountName asr-automation -Name myrecoveryplan-LBRG -Value asr-target -Encrypted $false 

New-AzureRmAutomationVariable -ResourceGroupName asr-target -AutomationAccountName asr-automation -Name myrecoveryplan-NSG -Value new-nsg-asr -Encrypted $false
New-AzureRmAutomationVariable -ResourceGroupName asr-target -AutomationAccountName asr-automation -Name myrecoveryplan-NSGRG -Value asr-target -Encrypted $false 

New-AzureRmAutomationVariable -ResourceGroupName asr-target -AutomationAccountName asr-automation -Name myrecoveryplan-TM -Value asrdemoarrow -Encrypted $false
New-AzureRmAutomationVariable -ResourceGroupName asr-target -AutomationAccountName asr-automation -Name myrecoveryplan-TMRG -Value asr-source -Encrypted $false 

#> Then go the link below to download the post script i create in order to import it as runbook.
#> https://raw.githubusercontent.com/javieriroman/azurepowershell/master/asr-demo-postscript.ps1

#> Go to the automation account, select runbook, select create new, put name and type "powershell"
#> Once create select the created runbook and select edit, copy the content from the link above, 
#> then select save and publish. Now you can use it on the recovery plan.  
