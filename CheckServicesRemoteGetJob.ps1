<#
.SYNOPSIS
List filtered services status and other details from remote VM's to HTML file

.DESCRIPTION
List filtered services status and other details from remote VM's to HTML file
How to use:
$Path > $DNSList (check and adjust folder location for your needs)
   put *.txt file with list of servers. Each server name in separate line. No delimiters.
   $EnvName is your filename without extension
Services are matched by Name and DisplayName at $Jobs
To work paths "$Path" and "${Path}\_LOG" needs to be created!

.NOTES

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

$ErrorActionPreference = "SilentlyContinue"

# get path
$Path = '\\servername\PS_Script'

# Environment name
$EnvName = "Ping_Pong_ENV_Region" #Read-Host -Prompt "Provide parameter file name without .extension"

# variable for logfile path(CSV UTF8)
$ReportDataFile = "${Path}\_LOG\status_service_data_${CurrentDateLog}.log"
$ReportErrorFile = "${Path}\_LOG\status_service_error_${CurrentDateLog}.log"
$ReportKerberosFile = "${Path}\_LOG\status_service_kerberos_${CurrentDateLog}.log" # Someday a loop maybe
# variable for logfile path(HTML text UTF8)
$ReportHTMLFile = "${Path}\_LOG\status_service_html_${CurrentDateLog}.html"
#variable for Select-Object
$SelectColumns = 'PSComputerName, Name, StartName, StartMode, State'
# variable for logo file
$Logo = '<img style=vertical-align:middle; src="\\Server_Name\PS_Script\CheckServicesRemoteGetJob\Logo.png" alt="logo">'


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
        @{ n = "Server Name";        e = { $_.PSComputerName } },
        'Server UpTime',
        @{ n = "Service";            e = { $_.Name } },
        @{ n = "Service Status";     e = { $_.State } },
        @{ n = "Start Mode";         e = { $_.StartMode } },
        @{ n = "Logon Account";      e = { $_.StartName } },
        @{ n = "Delayed Start";      e = { $_.DelayedAutoStart } }
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
Write-Host " $($ReportHTMLFile) " -BackgroundColor DarkCyan -ForegroundColor White

# servers NOT checked
#Write-Host " "
#Write-Host " Servers NOT checked " -BackgroundColor Red -ForegroundColor Black
#Write-Host "$($ListCompare)" -BackgroundColor Black -ForegroundColor Red

# Replace details in HTML
(Get-Content $ReportHTMLFile).replace('GreenClock',' &#128338; ') | Set-Content $ReportHTMLFile
(Get-Content $ReportHTMLFile).replace('RedClock', ' &#x1F534; ') | Set-Content $ReportHTMLFile

# open logfile (HTML UTF8) and temporary file cleanup
$ReportHTMLFile | clip
Invoke-Item $ReportHTMLFile
# Remove-Item $ReportDataFile
Remove-Item $ReportErrorFile
