#Updated on: Jan. 13, 2022
#Version: 1.00
#This script will enable hotadd cpu and mem on all powered on and powered off vm's in the servers.txt input file
#The servers.txt file should contain a list of all of the vm's in vCenter that you want to enable hotadd on and be in the same directory the script is being run from
#This will enabled hotadd on both powered on and powered off vm's.
#Note for the powered on vms this won't take affect until the vm's are powered off and powered on (not a reboot)
#This script requires that VMware PowerCLI is installed or it will not run"

write-host "***Start of script***" -ForegroundColor White	
write-host " "
write-host "checking if VMware PowerCLI is installed..."
$check = find-module -name vmware.powercli
if($check = $null){
    write-host "VMware PowerCLI cmdlet not installed, exiting..."
    write-host "please install by running the command: install-module -name vmware.powercli -scope currentuser"
    exit
}
write-host "VMware PowerCLI installed...continuing" -ForegroundColor Green

#Checking for servers.txt file which should be in same directory the script is being run from or it will fail
write-host "checking for servers.txt input file..."
if (-not(test-path -path ./servers.txt -pathtype leaf)){
    write-host "Input file not found: servers.txt" -ForegroundColor Red
    write-host "Please ensure the servers.txt is in the same directory as the script and re-run" -ForegroundColor Red
    write-host "script is exiting now..." -ForegroundColor Red
    exit
}

write-host "Input file found...continuing" -ForegroundColor Green
write-host " "
#Disable invalid vCenter SSL cert warnings
$setcert = Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

#Prompt for vCenter name
$vcenter = Read-Host "Enter vCenter name"

#Connect to vCenter - it will prompt for username and password
connect-viserver -server $vcenter -ErrorAction Stop

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
