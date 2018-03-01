<# 
    .DESCRIPTION 
        This runbook will attach an existing load balancer,backendpool,inbound nat rules and NSG to the vNics of the virtual machines, in the Recovery Plan group member define during failover. 
         
        This will create an azureEndPoint in Traffic Manager.
         
        Pre-requisites 
        All resources involved are based on Azure Resource Manager (NOT Azure Classic)

        - A Load Balancer with a backend pool and Inbound nat rules
        - Automation variables for the Load Balancer name, and Resource group, network security group name and Resource group, Traffic Manager name, and resource group

        To create the variables and use it towards multiple recovery plans, you should follow this pattern:
            
            New-AzureRmAutomationVariable -ResourceGroupName <RGName containing the automation account> -AutomationAccountName <automationAccount Name> -Name <recoveryPlan Name>-LB -Value  -Encrypted $false

            New-AzureRmAutomationVariable -ResourceGroupName <RGName containing the automation account> -AutomationAccountName <automationAccount Name> -Name <recoveryPlan Name>-LBRG -Value <name of the load balancer resource group> -Encrypted $false           

        The following AzureRm Modules are required
        - AzureRm.Profile
        - AzureRm.Resources
        - AzureRm.Compute
        - AzureRm.Network          
        - AzureRM.TrafficManager
#> 
param ( 
        [Object]$RecoveryPlanContext 
      ) 

Write-output $RecoveryPlanContext

# Set Error Preference	

$ErrorActionPreference = "Stop"

if ($RecoveryPlanContext.FailoverDirection -ne "PrimaryToSecondary") 
    {
        Write-Output "Failover Direction is not Azure, and the script will stop."
    }
else {
        $VMinfo = $RecoveryPlanContext.VmMap | Get-Member | Where-Object MemberType -EQ NoteProperty | select -ExpandProperty Name
        Write-Output ("Found the following VMGuid(s): `n" + $VMInfo)
            if ($VMInfo -is [system.array])
            {
                $VMinfo = $VMinfo[0]
                Write-Output "Found multiple VMs in the Recovery Plan"
            }
            else
            {
                Write-Output "Found only a single VM in the Recovery Plan"
            }
Try 
 {
    #Logging in to Azure...

    "Logging in to Azure..."
    $Conn = Get-AutomationConnection -Name AzureRunAsConnection 
     Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint

    "Selecting Azure subscription..."
    Select-AzureRmSubscription -SubscriptionId $Conn.SubscriptionID -TenantId $Conn.tenantid 
 }
Catch
 {
      $ErrorMessage = 'Login to Azure subscription failed.'
      $ErrorMessage += " `n"
      $ErrorMessage += 'Error: '
      $ErrorMessage += $_
      Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
 }
 Try
 {
    $TMNameVariable = $RecoveryPlanContext.RecoveryPlanName + "-TM"    
    $TMRgVariable = $RecoveryPlanContext.RecoveryPlanName + "-TMRG"    
    $TMName = Get-AutomationVariable -Name $TMNameVariable    
    $TMRgName = Get-AutomationVariable -Name $TMRgVariable
    $trafficmanager = Get-AzureRmTrafficManagerProfile -Name $TMName -ResourceGroupName $TMRgName        
 }
Catch
 {
    $ErrorMessage = 'Failed to retrieve Load Balancer info from Automation variables.'
    $ErrorMessage += " `n"
    $ErrorMessage += 'Error: '
    $ErrorMessage += $_
    Write-Error -Message $ErrorMessage `
                   -ErrorAction Stop
 }
Try
 {
    $LBNameVariable = $RecoveryPlanContext.RecoveryPlanName + "-LB"    
    $LBRgVariable = $RecoveryPlanContext.RecoveryPlanName + "-LBRG"    
    $LBName = Get-AutomationVariable -Name $LBNameVariable    
    $LBRgName = Get-AutomationVariable -Name $LBRgVariable
    $LoadBalancer = Get-AzureRmLoadBalancer -Name $LBName -ResourceGroupName $LBRgName        
 }
Catch
 {
    $ErrorMessage = 'Failed to retrieve Load Balancer info from Automation variables.'
    $ErrorMessage += " `n"
    $ErrorMessage += 'Error: '
    $ErrorMessage += $_
    Write-Error -Message $ErrorMessage `
                   -ErrorAction Stop
 }
 Try
 {
    $NSGNameVariable = $RecoveryPlanContext.RecoveryPlanName + "-NSG"    
    $NSGRgVariable = $RecoveryPlanContext.RecoveryPlanName + "-NSGRG"    
    $NSGName = Get-AutomationVariable -Name $NSGNameVariable    
    $NSGRgName = Get-AutomationVariable -Name $NSGRgVariable
    $NSG = Get-AzureRmNetworkSecurityGroup -Name $NSGName -ResourceGroupName $NSGRgName        
 }
Catch
 {
    $ErrorMessage = 'Failed to retrieve Network Security Group info from Automation variables.'
    $ErrorMessage += " `n"
    $ErrorMessage += 'Error: '
    $ErrorMessage += $_
    Write-Error -Message $ErrorMessage `
                   -ErrorAction Stop
 }
    #Getting VM details from the Recovery Plan Group, and associate the vNics with the Load Balancer
Try
 {
    $VMinfo = $RecoveryPlanContext.VmMap | Get-Member | Where-Object MemberType -EQ NoteProperty | select -ExpandProperty Name
    $VMs = $RecoveryPlanContext.VmMap
    $vmMap = $RecoveryPlanContext.VmMap
    $number = 0 ;
    foreach ($VMID in $VMinfo)
    {   
        $VM = $vmMap.$VMID
        Write-Output $VM.ResourceGroupName
        Write-Output $VM.RoleName    
        $AzureVm = Get-AzureRmVm -ResourceGroupName $VM.ResourceGroupName -Name $VM.RoleName    
        If ($AzureVm.AvailabilitySetReference -eq $null)
        {
            Write-Output "No Availability Set is present for VM: `n" $AzureVm.Name
        }
        else
        {
            Write-Output "Availability Set is present for VM: `n" $AzureVm.Name
        }
        #Join the VMs NICs to backend pool of the Load Balancer
        $nicid = $AzureVm.NetworkProfile.NetworkInterfaces[0]
        $ARMNic = Get-AzureRmResource -ResourceId $nicid.Id
        $Nic = Get-AzureRmNetworkInterface -Name $ARMNic.Name -ResourceGroupName $ARMNic.ResourceGroupName
        $Nic.IpConfigurations[0].LoadBalancerBackendAddressPools.Add($LoadBalancer.BackendAddressPools[0]); 
        #Join the VMs NICs the inbound nat rules of the Load Balancer 
        $Nic.IpConfigurations[0].LoadBalancerInboundNatRules = $LoadBalancer.InboundNatRules[$number]
        #Join the VMs NICs the Network Security Group
        $Nic.NetworkSecurityGroup = $NSG
        
        $Nic | Set-AzureRmNetworkInterface
        Write-Output "Done configuring Load Balancing for VM" $AzureVm.Name 
        $number = $number + 1;   
    }
 }
Catch
 {
    $ErrorMessage = 'Failed to associate the VM with the Load Balancer.'
    $ErrorMessage += " `n"
    $ErrorMessage += 'Error: '
    $ErrorMessage += $_
    Write-Error -Message $ErrorMessage `
                   -ErrorAction Stop
 }
 Try
 {
    New-AzureRmTrafficManagerEndpoint -name secondary -ProfileName $trafficmanager.Name -ResourceGroupName $trafficmanager.ResourceGroupName -Type AzureEndpoints -EndpointStatus Enabled -TargetResourceId $LoadBalancer.FrontendIpConfigurations.publicipaddress.Id      
 }
Catch
 {
    $ErrorMessage = 'Failed to add the Public IP from the loadbalancer to the TrafficMananger Endpoints'
    $ErrorMessage += " `n"
    $ErrorMessage += 'Error: '
    $ErrorMessage += $_
    Write-Error -Message $ErrorMessage `
                   -ErrorAction Stop
 }
}
