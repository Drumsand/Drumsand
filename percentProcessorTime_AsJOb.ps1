#Requires -Version 5.1
# but it will query VM's up to V2

# list of servers to be checked
$servers = "KBNDBSQL44", "KBNDVSQL108", "XAUDZSQL02", "XAUDZSQL03"<#, "MAIDBSQL18", "MAIDBSQL24", "STNDBSQL10", "STNTSSQL06", "STNDBSQL09", "STNDBSQL12", "STNDBSQL11", "STNDBSQL02", "RIODBSQL01", "XAUNASQL07", "XAUDBSQL06", "XHKDBSQL31", "XHKDBSQL130" #>

# Properties to present in table from functions
$props_CoresConf      = "ServerName", "CoreID", "NumberOfCores", <# "NumberOfEnabledCore", #> "NumberOfLogicalProcessors"# , "SocketDesignation" win2k3 property
$props_CoresUsage     = "ServerName", "TimeStamp", @{ Expression = 'UsageValue'; align = "right" }, @{ Expression = 'CoreName'; align = "right" }

# sort properties of fucntion: Get-CoresUsage
$props_Sort_CoresUsage = "ServerName", @{ Expression = 'UsageValue'; Descending = $true }<# , @{ Expression = 'CoreName'; Ascending = $true } #>

$ErrorActionPreference = "SilentlyContinue" # Tested all errors due to Powershell V4 installed on older machines
$s = New-PSSession -Comp $servers -ea 0 # -ThrottleLimit 4 #-InDisconnectedSession

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

# jobs to send funtions as query for opened sessions
$CoresConf = Invoke-Command -ScriptBlock ${function:Get-CoresConf} -AsJob -Session $s | receive-job -wait -AutoRemoveJob
$coresUsage = Invoke-Command -ScriptBlock ${function:Get-CoresUsage} -AsJob -Session $s | receive-job -wait -AutoRemoveJob

# present data
# Check which servers didn't get to pssession. Not checked.
$notChecked = (compare-object $servers $s.computername).InputObject
# split
$ofs = ', '
if ($notChecked) { Write-Warning "Servers that cannot be connected: $($notChecked -split $ofs)" }

$CoresConf | Format-Table -Property $props_CoresConf -Auto

# Present value of total processor use with new variable $coresUsageTotal
$coresUsageTotal = $coresUsage | Where-Object { $_.CoreName -eq "_Total" }
foreach ($srv in $s.ComputerName) { "Total percent of processor usage on $($srv) is $(($coresUsageTotal | Where-Object { $_.PSComputerName -eq $srv }).UsageValue) %" }
# Remove total usage number from $coresUsage
$coresUsage = $coresUsage | Where-Object { $_.CoreName -ne "_Total" }
# present results of cores use on each server
$coresUsage | Sort-Object -Property $props_Sort_CoresUsage | Format-Table -Property $props_CoresUsage -AutoSize

# security wise - close all gates behind you
Remove-PSSession $s
