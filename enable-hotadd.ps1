#This script assumes you already have VMware PowerCLI installed using the command "install-module -name VMware.PowerCLI -scope CurrentUser"
write-host "start of script" -ForegroundColor White	
write-host "checking if VMware PowerCLI is installed..."
$check = find-module -name vmware.powercli
if($check = $null){
    write-host "VMware PowerCLI cmdlet not installed, exiting..."
    write-host "please install by running the command: install-module -name vmware.powercli -scope currentuser"
    exit
}

#Disable invalid vCenter SSL cert warnings
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

#Prompt for vCenter name
$vcenter = Read-Host "Enter vCenter name"

#Connect to vCenter - it will prompt for username and password
connect-viserver -server $vcenter

#Function to enable Hot Add Memory
Function Enable-MemHotAdd($vm){
    $vmview = Get-VM $vm | Get-View 
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec

    $extra = New-Object VMware.Vim.optionvalue
    $extra.Key="mem.hotadd"
    $extra.Value="true"
    $vmConfigSpec.extraconfig += $extra

    $vmview.ReconfigVM($vmConfigSpec)
}

#Function to enable Hot Add CPU
Function Enable-CpuHotAdd($vm){
    $vmview = Get-VM $vm | Get-View 
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec

    $extra = New-Object VMware.Vim.optionvalue
    $extra.Key="vcpu.hotadd"
    $extra.Value="true"
    $vmConfigSpec.extraconfig += $extra

    $vmview.ReconfigVM($vmConfigSpec)
}

#Function to enable Hot Add CPU and Memory (but this doesn't work in vCenter 6.7, will only work in vCenter 6.5 and below)
Function memcpu($vm){ 
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $spec.CpuHotAddEnabled = $true
    $spec.MemoryHotAddEnabled = $true
    $vm.ExtensionData.ReconfigVM($spec)
      }
 
######Start of main script
#Get list of servers to enable hot add on from file name below
#File should be in same directory the script is being run from or it will fail

Get-Content "./servers.txt" | %{ 
     $vm = Get-VM -Name $_ 

#Check if hot add mem and cpu is already enabled, if both are already enabled it will skip that vm
 if(-not $vm.ExtensionData.Config.cpuHotAddEnabled -or -not $vm.ExtensionData.Config.memoryHotAddEnabled)
    {
     Enable-MemHotAdd $vm
     write-host "enabled hot add mem on vm: $vm" -ForegroundColor Yellow
     Enable-CpuHotAdd $vm
     write-host "enabled hot add cpu on vm: $vm" -ForegroundColor Yellow
     memcpu $vm
     $Result = ($vm | select ExtensionData).ExtensionData.config | Select Name, MemoryHotAddEnabled, CpuHotAddEnabled, CpuHotRemoveEnabled  
     Write-Host $Result
    }
        else {
              write-host "hot add mem and cpu already enabled on vm: $vm" -ForegroundColor Green
        }
}
write-host "end of script" -ForegroundColor White	
#####End of script
