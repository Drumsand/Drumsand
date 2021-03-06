<#
.SYNOPSIS
List filtered services status and other details from remote VM's to HTML file

.DESCRIPTION
List filtered services status and other details from remote VM's to HTML file
How to use:
   put *.txt file with list of servers to "Ping_Pong" folder. Each server name in separate line. No delimiters.
   $EnvName is your *.txt filename without extension
   Services are matched by Name and DisplayName at $Jobs

.NOTES
v 1.06 | 2021.02.17 |
- $Path = $PSScriptRoot / script can be run from any location

v 1.05 | 2020.06.10 |
- CIM CmdLets only now

v 1.04 | 2020.04.22 |
- Server Uptime added to HTML report
- CSS classes related to column dimensions added
- ` (ticks) removed (when possible more to follow)

v 1.03 | 2020.04.16 |
- $StatusColor now uses CSS classes
- PSSession -IncludePortInSPN loop waiting to be made

v 1.02 | 2019.12.02 |
- IE css to present table nested
- column names expressions
- additional CSS to highlight status of a service in logfile
    https://jamesdatatechq.wordpress.com/2014/12/23/how-to-create-an-html-table-from-powershell/
- CSS 3 blink feature used for services in starting status
- servers not checked comparison in (HTML) log only now

v 1.01 | 2019.08.11 |
- servers not checked comparison on screen and log (HTML)
- prepared future menu for environments to be checked

.LINK
https://raw.githubusercontent.com/Drumsand/Drumsand/master/CheckServicesRemoteGetJob.ps1
#>

Clear-Host

#get date for logfile unique filename
$CurrentDateLog = Get-Date -format "yyyy-MM-dd_HH-mm-ss"
$CurrentDateText = Get-Date -format "yyyy-MM-dd HH:mm"

# $ErrorActionPreference = "SilentlyContinue"

# get path
$Path = $PSScriptRoot

# environment name
$EnvName = "EnvName" #Read-Host -Prompt "Provide parameter file name without .extension"o

# check if log folder exists / then create
$invocation = (Get-Variable MyInvocation).Value
$directoryPath = Split-Path $invocation.MyCommand.Path
$directoryPathForLog = $directoryPath + "\" + "_LOG"
if (!(Test-Path -path $directoryPathForLog)) {
    New-Item -ItemType directory -Path $directoryPathForLog
    Write-Host "Folder path has been created successfully at: " $directoryPathForLog
}
else {
    Write-Host "The given folder path $directoryPathForLog already exists";
}

# variable for logfile path(CSV UTF8)
$ReportDataFile = "${Path}\_LOG\status_service_data_${CurrentDateLog}.log"
$ReportErrorFile = "${Path}\_LOG\status_service_error_${CurrentDateLog}.log"
$ReportKerberosFile = "${Path}\_LOG\status_service_kerberos_${CurrentDateLog}.log" # Someday a loop maybe
# variable for logfile path(HTML text UTF8)
$ReportHTMLFile = "${Path}\_LOG\status_service_html_${CurrentDateLog}.html"
#variable for Select-Object
$SelectColumns = 'PSComputerName, Name, StartName, StartMode, State'
# variable for logo file
$Logo = '<img style=vertical-align:middle; src="../_RES/Logo.png" alt="logo">'

# $StatusColor CSS classes to splash some life into the HTML
$StatusColor = @{ `
        'Continue Pending' = ' class="Continue-Pending">Continue Pending<'; # The service has been paused and is about to continue.
    Paused                 = ' class="Paused">Paused<'; # The service is paused.
    'Pause Pending'        = ' class="Pause-Pending ">Pause Pending<'; # The service is in the process of pausing.
    Running                = ' class="Running">Running<'; # The service is running.
    'Start Pending'        = ' class="blink-bg">Starting<'; # The service is in the process of starting.
    Stopped                = ' class="Stopped">Stopped<'; # The service is not running.
    'Stop Pending'         = ' class="Stopping">Stopping<'; # The service is in the process of stopping.
    Disabled               = ' class="Disabled">Disabled<'; # The startup mode is set to DISABLED
    Manual                 = ' class="Manual">Manual<'; # The startup mode is set to MANUAL
    True                   = ' class="True-Delay">True<'; # Delayed startup: True
    False                  = ' class="False-Delay">False<'; # Delayed startup: False
    'Server Name'          = ' class="col-sn-width">Server Name<'; # column width
    'Server Uptime'        = ' class="col-ut-width">Server Uptime<'; # column width
    'Service Status'       = ' class="col-ss-width">Service Status<'; # column width
    'Delayed Start'        = ' class="col-ds-width">Delayed Start<'; # column width
    'Start Mode'           = ' class="col-sm-width">Start Mode<'; # column width
}

# server list to check from file (CSV)
#
$DNSList = @(Get-Content "${Path}\Ping_Pong\$($EnvName).txt")
$s = New-PSSession -ComputerName $DNSList -Name Marty-CheckService
# Write-Output $s

$Jobs = Invoke-Command -Session $s {
    $Boot = (Get-CimInstance -ClassName win32_operatingsystem | Select-Object LastBootUpTime).lastbootuptime
    $Today = Get-Date
    $UpTime = New-TimeSpan -start $Boot -end $Today
    $CimOSUpTime = If ($UpTime.Days -gt 23) { ' RedClock ' + $UpTime.Days + "d " + $UpTime.Hours + "h " } else { ' GreenClock ' + $UpTime.Days + "d " + $UpTime.Hours + "h " }
    # (Get-Date) - (Get-CimInstance Win32_OperatingSystem -ComputerName $server).LastBootupTime

    Get-CimInstance -ClassName win32_service |
    Where {
        $_.Name -match "AOS60" -or
        $_.Name -match "ATLAS_" -or <# POS Services #>
        $_.Name -match "MSSQL" -or
        $_.Name -match "SQLAgent" -or
        $_.Name -match "SQLSERVERAGENT" -or
        $_.Name -match "ReportServer" -or
        $_.Name -match "Lasernet" -or
        $_.Name -match "IISADMIN" -or <# IIS #>
        $_.Name -match "W3SVC" -or <# IIS / World Wide Web Publishing Service #>
        $_.Name -match "WMSVC" -or <# Web Management Service #>
        $_.Name -match "CRM" -or
        $_.Name -match "MSCRM" -or
        $_.Name -match "Sharepoint" -or <# Sharepoint #>
        $_.Name -match "appFabric" -or <# Sharepoint appFabric Epos #>
        ( $_.Name -eq "Spooler" -and $_.PSComputerName -like "*OMS*" ) -or
        $_.DisplayName -match "Dynamics 365" -or
        $_.DisplayName -match "Mongo" -and
        !($_.Name -match "MSSQLFDLauncher")                 <# non-essential SQL #>
        # $_.Name -match "RSoPProv" `             -or         <# The one with manual startup (test) #>
        # $_.Name -match "tzautoupdate" `         -or         <# The one with disabled startup (test) #>
    } |
    Select-Object -Property *, @{n = 'Server UpTime'; e = { $CimOSUpTime } }
} -AsJob

# Jobs progress simple no info
Write-Host " `nJobs running " -F DarkCyan -NoNewline
while (($Jobs.State -eq "Running") -and ($Jobs.State -ne "NotStarted")) {
    Write-Host '.' -NoNewline -F DarkCyan
    Start-Sleep -Seconds 1
}
# New line for nice output
Write-Host "`nJobs finished" -F DarkCyan

# receive job to list services status | sort | export logfile (CSV UTF8)
Get-Job | Wait-Job | Receive-Job |
Sort-Object PSComputerName, Service |
Export-Csv -Path $ReportDataFile -NoTypeInformation -Encoding UTF8 -Delimiter ";"


# Kill opened PS Sessions
Write-Host "Removing Powershell sessions from remote computers"
Remove-PSSession $s # -Verbose
# $s | % { Remove-PSSession -Session $s } -Verbose


# Create logfile (HTML UTF8)
# ---

$Title = "Report: Status on machines. Generated on $($CurrentDateText)"

# CSS style for logfile (HTML UTF8)
$css = @"
<style>
body 	{ background: #000; color: #E3E3E3; }
table   { table-layout: fixed; width: 98%; margin: auto; font-family: Segoe UI; border: color: #DDD; }
h1      { text-align: left; font-size: 12px; text-align: left; font-family: Segoe UI; display: table-cell; vertical-align: middle; }
h5		{ text-align: left; font-size: 12px; text-align: left; font-family: Segoe UI;}
th      { text-align: left; font-size: 12px; text-align: left; font-family: Segoe UI; background: #333333; color: #E6E8E9; max-width: 400px; padding: 3px 10px; position: sticky; top: 0px; }
td      { text-align: left; font-size: 12px; padding: 3px 20px; color: 476070; }
tr      { background: #2E5266; color: #E3E3E3; }
tr:nth-child(even)  { background: #2E5266; color: #B3B3B3; }
tr:nth-child(odd)   { background: #6E8898; color: #E3E3E3; }

.col-sn-width       { width: 120px; }       /* ServerName column width */
.col-ut-width       { width: 90px; }        /* UpTime column width */
.col-ss-width       { width: 150px; }       /* Service Status column width */
.col-ds-width       { width: 80px; }        /* Delayed Start column width */
.col-sm-width       { width: 80px; }        /* Start Mode column width */

.Continue-Pending   { background: #FE2020; color: #92977E; }
.Paused             { background: #FE2020; color: #2A9D8F; }
.Pause-Pending      { background: #FE2020; color: #E9C46A; }
.Running            { background: #06EB76; color: #FFFFFF; }
.Stopped            { background: #FE2020; color: #CAFAFE; }
.Stop-Pending       { background: #FE2020; color: #907163; }
.Disabled           { background: #FFE400; color: #FE2020; }
.Manual             { background: #272727; color: #66FCF1; }
.True-Delay         { background: #5D737E; color: #F0F7EE; }
.False-Delay        { background: #5D737E; color: #D3D3D3; }

.blink-bg{
		color:#3FEEE6;
		background: #FE2020;
		width: 100%;
		display: table-cell;
		animation: blinkingBackground 2s infinite;
	}
	@keyframes blinkingBackground{
		0%		{ background: #10C018;}
		25%		{ background: #1056C0;}
		50%		{ background: #EF0A1A;}
		75%		{ background: #254878;}
		100%	{ background: #04A1D5;}
	}
</style>
"@

# CSS light theme
# .Continue-Pending   { color:#92977E; background: #FE2020 }
# .Paused             { color:#2A9D8F; background: #FE2020 }
# .Pause-Pending      { color:#E9C46A; background: #FE2020 }
# .Running            { color:#FFFFFF; background: #06EB76 }
# .Stopped            { color:#CAFAFE; background: #FE2020 }
# .Stop-Pending       { color:#907163; background: #FE2020 }
# .Disabled           { color:#FE2020; background: #FFE400 }
# .Manual             { color:#66FCF1; background: #272727 }

# Values for log. Services
$GService = Import-Csv $ReportDataFile -Delimiter ";" |
Select-Object (
    @{ n = "Server Name"; e = { $_.PSComputerName } },
    'Server UpTime',
    @{ n = "Service"; e = { $_.Name } },
    @{ n = "Service Status"; e = { $_.State } },
    @{ n = "Start Mode"; e = { $_.StartMode } },
    @{ n = "Logon Account"; e = { $_.StartName } },
    @{ n = "Delayed Start"; e = { $_.DelayedAutoStart } }
) | ConvertTo-HTML -AS Table -Fragment -PreContent '<table><colgroup><col/></colgroup><tr><th><h1>Services on Servers</h1></th></tr>' | Out-String

# Logfile (HTML UTF8) status color
$StatusColor.Keys | ForEach-Object { $GService = $GService -replace ">$_<", ($StatusColor.$_) }


# compare lists to know servers not checked
$Check1 = $DNSList | Sort-Object -Unique
$Check2 = (Import-Csv $ReportDataFile -Delimiter ";").PSComputerName | Sort-Object -Unique
(Compare-Object $Check1 $Check2).InputObject | Out-String | Out-File $ReportErrorFile


# convert Array to CSV
(Get-Content $ReportErrorFile) | % { '"' + $_ + '";' } | Set-Content $ReportErrorFile
@('Kerberos_hardened;') + (Get-Content $ReportErrorFile) | Set-Content $ReportErrorFile



# In future
# $DNS_SPN = @(Get-Content $ReportErrorFile.kerberos_hardened)
# $sb = New-PSSession -ComputerName $DNS_SPN -IncludePortInSPN -Name Marty-CheckSrvKerberos
# $sb


$GError = Import-Csv $ReportErrorFile -Delimiter ";" |
ConvertTo-Html -AS Table -Fragment -PreContent '<table><colgroup><col/></colgroup><tr><th><h1>Servers not checked </h1></th></tr>' | Out-String


#
# Save log file HTML
#
ConvertTo-HTML -Title $Title -head $css -PostContent $GService, $GError -PreContent "
    <!--[if IE]><style>
    td { border-color: black; border-style: solid; border-width: 1px 1px 0px 0; }
    </style><![endif]-->

    <table><colgroup><col/></colgroup><tr><th><h1> $($Logo) $($Title)</h1></th></tr>
    " |
Out-File $ReportHTMLFile


# put on-screen
# $onscreen = Import-Csv $ReportDataFile -Delimiter ";"
# $onscreen | Format-Table -AutoSize -Wrap

$onscreen = Import-Csv $ReportErrorFile -Delimiter ";"
$onscreen | Format-Table -AutoSize -Wrap


# write confirmation that logfile (HTML UTF8) has been created with list of servers checked
# Clear-Host
Write-Host ' Jobs Finished ' -BackgroundColor DarkCyan -ForegroundColor White
Write-Host " "
Write-Host " Log file path stored in clipboard automatically " -BackgroundColor DarkCyan -ForegroundColor White
Write-Host " $($ReportHTMLFile) " #-BackgroundColor DarkCyan -ForegroundColor White

# servers NOT checked
#Write-Host " "
#Write-Host " Servers NOT checked " -BackgroundColor Red -ForegroundColor Black
#Write-Host "$($ListCompare)" -BackgroundColor Black -ForegroundColor Red

# Replace details in HTML
(Get-Content $ReportHTMLFile).replace('GreenClock', ' &#128338; ') | Set-Content $ReportHTMLFile
(Get-Content $ReportHTMLFile).replace('RedClock', ' &#x1F534; ') | Set-Content $ReportHTMLFile

# open logfile (HTML UTF8) and temporary file cleanup
$ReportHTMLFile | clip
Invoke-Item $ReportHTMLFile
# Remove-Item $ReportDataFile
Remove-Item $ReportErrorFile
