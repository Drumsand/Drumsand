#Requires -Version 5.1
# but it will query VM's up to V3

# list of servers to be checked
$servers = 

# Properties to present in table from functions
$props_VMType         = "ServerName", "Model", "Manfacturer", "PSComputerName"
$props_CoresConf      = "ServerName", "CoreID", "NumberOfCores", <# "NumberOfEnabledCore", #> "NumberOfLogicalProcessors"# , "SocketDesignation" win2k3 property
$props_CoresUsage     = "ServerName", "TimeStamp", @{ Expression = 'UsageValue'; align = "right" }, @{ Expression = 'CoreName'; align = "right" }

# sort properties of fucntion: Get-CoresUsage
$props_Sort_CoresUsage = "ServerName", @{ Expression = 'UsageValue'; Descending = $true }<# , @{ Expression = 'CoreName'; Ascending = $true } #>

$ErrorActionPreference = "SilentlyContinue" # Tested all errors due to Powershell V4 installed on older machines
$s = New-PSSession -Comp $servers -ea 0 # -ThrottleLimit 4 #-InDisconnectedSession

function Get-VMType {
    $VMType = Get-CimInstance -Class Win32_ComputerSystem | Select-Object Model, Manufacturer, PSComputerName
    foreach ($VM in $VMType) {
        New-Object pscustomobject -Property @{
            ServerName = $env:computername
            VM_Model   = $VM.Model
            VM_Type    = $VM.Manufacturer
        }
    }
}

function Get-CoresConf {
    if ($PSVersionTable.PSVersion.Major -le 5) {
        $CoresConf = Get-Ciminstance -ClassName Win32_Processor | Select-Object DeviceID, NumberOfCores, NumberOfEnabledCore, NumberOfLogicalProcessors
    }
    else {
        $CoresConf = Get-CimInstance -Query "Select DeviceID, NumberOfCores, NumberOfEnabledCore, NumberOfLogicalProcessors, SocketDesignation from Win32_Processor" # this could be us, but we keep old PS.4!
    }
    foreach ($Core in $CoresConf) {
        New-Object pscustomobject -Property @{
            ServerName                = $env:computername
            NumberOfSockets           = $CoresConf.count
            CoreID                    = $core.DeviceID
            NumberOfCores             = $core.NumberOfCores
            # NumberOfEnabledCore       = $core.NumberOfEnabledCore
            NumberOfLogicalProcessors = $core.NumberOfLogicalProcessors
        }
    }
}
function Get-CoresUsage {
    if ($PSVersionTable.PSVersion.Major -le 5) {
        $res = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor | Select-Object Name, PercentProcessorTime
    }
    else {
        $res = Get-CimInstance -Query "Select Name, PercentProcessorTime from Win32_PerfFormattedData_PerfOS_Processor" # this could be us, but we keep old PS.4!
    }
    foreach ($single in $res) {
        New-Object pscustomobject -Property @{
            TimeStamp  = Get-Date -format "yyyy-MM-dd HH:mm:ss"
            ServerName = $env:computername
            UsageValue = ($single.PercentProcessorTime).ToString("d3")
            CoreName   = $single.Name
        }
    }
}

# jobs to send funtions for opened sessions
$VMType     = Invoke-Command -ScriptBlock ${function:Get-VMtype} -AsJob -Session $s | receive-job -wait -AutoRemoveJob
$CoresConf  = Invoke-Command -ScriptBlock ${function:Get-CoresConf} -AsJob -Session $s | receive-job -wait -AutoRemoveJob
$coresUsage = Invoke-Command -ScriptBlock ${function:Get-CoresUsage} -AsJob -Session $s | receive-job -wait -AutoRemoveJob

# present data
# Check which servers didn't get to pssession. Not checked.
$notChecked = (compare-object $servers $s.computername).InputObject
# split
$ofs = ', '
if ($notChecked) { Write-Warning "Servers that cannot be connected: $($notChecked -split $ofs)" }
""

# Results
#
# Present value of total processor use with new variable $coresUsageTotal
# VM type and model
# Cores configuration and usage
$coresUsageTotal = $coresUsage | Where-Object { $_.CoreName -eq "_Total" }
foreach ($srv in $s.ComputerName) { 
    "Total percent of processor usage on $($srv) is $(($coresUsageTotal | Where-Object { $_.PSComputerName -eq $srv }).UsageValue) %"
    "VM type on $($srv) is $(($VMType | Where-Object { $_.PSComputerName -eq $srv }).VM_Type), model $(($VMType | Where-Object { $_.PSComputerName -eq $srv }).VM_Model)"
    $CoresConf | Where-Object { $_.PSComputerName -eq $srv } | Format-Table -Property $props_CoresConf -Auto
    # Remove total usage number from $coresUsage
    $coresUsage = $coresUsage | Where-Object { $_.CoreName -ne "_Total" }
    # present results of cores use on each server
    $coresUsage | Where-Object {$_.PSComputerName -eq $srv} | Sort-Object -Property $props_Sort_CoresUsage | Format-Table -Property $props_CoresUsage -AutoSize
    ""
}

# security wise - close all gates behind you
Remove-PSSession $s
