<#
.SYNOPSIS
Add multiple printers to multiple print servers. Period.
For comments and needed functions please contact: drumsand@gmail.com
Any updates will be available in link below [.LINK]

.DESCRIPTION
Script checks if drivers are installed on given print servers first.
When any driver is missing, script stops and informs about action to be taken before
script coulb be run again.
Script installs printers on each print server first.
Log is provided both on-screen and in log file.
Log file location is presented on-screen.
How to use:
   Put *.csv file with list of servers to main folder. Delimiter is ";" (semicolon).
   PrinterName;Driver;PortName;Location;Comment;Shared;ShareName - this is header of CSV file
   Check print servers variable: [string[]]$servers = (...)
   Run script

.NOTES
v 1.03 | 2021.02.22 |
- Drivers check loop made separate. Allows to stop script before adding ports/printers,
    $driverCheck custom object allows to check if driver missing,
    script won't continue before all drivers are present,
- path changed to $PSScriptRoot. Allows to run script from any location,
- log available for both onscreen and log file,
- log file folder check/create made,
- function Get-LogDate and parameters ready.

v 1.02 | 2020.04.16 |
- boolean check for driver/port/printer.

v 1.01 | 2019.08.16 |
- basic script is ready.

.LINK
https://raw.githubusercontent.com/Drumsand/Drumsand/master/Add_multiple_printers_ports_multiple_servers.ps1
#>


[string[]]$servers = "KBNBSOMS11", "KBNBSOMS12", "KBNTSOMS11", "KBNTSOMS12" # KBN 2020 print servers
# [string[]]$servers = "SOMBSOMS11", "SOMBSOMS12", "SOMTSOMS11", "SOMTSOMS12" # SOM 2020 print servers
# [string[]]$servers = "XAUTSOMS11", "XAUTSOMS12", "XAUBSOMS11", "XAUBSOMS12" # XAU 2020 print servers

Clear-Host
$ErrorActionPreference = "SilentlyContinue"

# get path
$Path = $PSScriptRoot

# variables
[string[]]$logFolder = "_LOG_printers"
[string[]]$logPath = "${path}\$logFolder"
[string[]]$ConfFile = "Printer_conf_list_CSV.csv"
[array[]] $printers = Import-Csv "${path}\$($ConfFile)" -Delimiter ";" #semicolon
[array[]] $driversConf = $printers.Driver | Select-Object -Unique
#  $driversConf +="Kiwi" # for testing break full loop logic
[array[]] $driverCheck = @()
[string[]]$dateFile = Get-Date -format "yyyyMMdd_HHmmss"
# progress loop counters
$i = $j = 1

$teeParam = @{
    FilePath = "$logPath\$($DateFile)_prn_install_log.log"
    Append   = $true
}

# function that updates time in log entries
function Get-logDate() {
    Get-Date -format "yyyy-MM-dd HH:mm"
}

# check if log folder exists / then create if needed
$invocation = (Get-Variable MyInvocation).Value
$directoryPath = Split-Path $invocation.MyCommand.Path
$directoryPathForLog = $directoryPath + "\" + $logFolder
if (!(Test-Path -path $directoryPathForLog)) {
    New-Item -ItemType directory -Path $directoryPathForLog
    "`n`rFolder path has been created successfully at: $directoryPathForLog`n`r"
}
else {
    "`n`rOK! The given folder path $directoryPathForLog already exists`n`r"
}

# notify about checking driver
"********************************************************************************************************" | Tee-Object @teeParam
" Checking if drivers are installed on $($servers -join ', ') server(s) "                                  | Tee-Object @teeParam
" `tPrinter configuration file: ${path}\$($ConfFile)"                                                      | Tee-Object @teeParam
"********************************************************************************************************" | Tee-Object @teeParam
" "                                                                                                        | Tee-Object @teeParam

# create loop to check if drivers eaxist on each server
foreach ($server in $servers) {
    foreach ($driverName in $DriversConf) {

        # if/else to check if printer driver is installed (not installed breaks loop)
        $printDriverExists = $([bool]( Get-PrinterDriver -ComputerName $server -name $driverName ))

        if ($printDriverExists -eq $true) {
            "$(Get-logDate) | $($server) | Printer Driver: $($driverName) is installed" | Tee-Object @teeParam
        }
        else {
            $driverCheck += [PSCustomObject]@{
                Server_Name    = $server
                Missing_Driver = $driverName
            }
            $t = $host.ui.RawUI.ForegroundColor
            $host.ui.RawUI.ForegroundColor = "RED"
            "$(Get-logDate) | $($server) | Printer Driver: $($driver) not installed!" | Tee-Object @teeParam
            $host.ui.RawUI.ForegroundColor = $t
        }
    }
}

if ($driverCheck) {
    "`n$(Get-logDate) | $($server) | Listed driver(s) are missing. Check log and update drivers before continue`n" | Tee-Object @teeParam
    break
}
else {
    # notify about process starting
    " "                                                                                                        | Tee-Object @teeParam
    "********************************************************************************************************" | Tee-Object @teeParam
    " Adding printers on $($servers -join ', ') server(s) "                                                    | Tee-Object @teeParam
    " `tPrinter configuration file: ${path}\$($ConfFile)"                                                      | Tee-Object @teeParam
    "********************************************************************************************************" | Tee-Object @teeParam
    " "                                                                                                        | Tee-Object @teeParam
}

# test break
# break

# create loop to add printer on each server
foreach ($server in $servers) {
    # update counter and write progress - someday maybe
    # Write-Progress -Id 0 -activity "Print server pass . . ." -status "Print Server: $($i) of $($servers.Count)" -CurrentOperation $server -PercentComplete (($i++ / $servers.count) * 100)
    foreach ($printer in $printers) {
        # update counter and write progress / need to find way to use when if/else statement present
        # Write-Progress -Id 1 -ParentId 0 -activity "Installing printers . . ." -status "Printer: $($j) of $($printers.Count)" -CurrentOperation $printer.PrinterName -PercentComplete (($j++ / $printers.count) * 100)

        # Confirmation before adding printer port
        "$(Get-logDate) | $($server) | $($printer.Printername) | Adding printer port: $($printer.Portname)" | Tee-Object @teeParam

        # if/else to check if printer port exists on server
        $portExists = $([bool]( Get-Printerport -ComputerName $server -Name $printer.Portname ))

        if ($portExists -eq $true) {
            "$(Get-logDate) | $($server) | $($printer.Printername) | Printer port: $($printer.Portname) already exists" | Tee-Object @teeParam
        }

        else {
            Add-PrinterPort -ComputerName $server -Name $printer.Portname -PrinterHostAddress  $printer.Portname
            "$(Get-logDate) | $($server) | $($printer.Printername) | Printer port: $($printer.Portname) added" | Tee-Object @teeParam
        }

        # Adding printer on selected port now
        "$(Get-logDate) | $($server) | $($printer.Printername) | Adding printer: $($printer.Printername) with driver: $($printer.Driver) on port: $( $printer.Portname)" | Tee-Object @teeParam
        Add-Printer -ComputerName $server -Name $printer.Printername -DriverName $printer.Driver -PortName $printer.Portname -Comment $printer.Comment -Location $printer.Location -ErrorAction 0 |
        Set-PrintConfiguration -PaperSize A4

        # Get-Printer -ComputerName $server -Name $printer.Printername / Check if printer is installed
        $printerExists = $( [bool]( Get-Printer -ComputerName $server -Name $printer.Printername ) )

        if ( $printerExists -eq $true ) {
            $t = $host.ui.RawUI.ForegroundColor
            $host.ui.RawUI.ForegroundColor = "Green"
            Write-Output "$(Get-logDate) | $($server) | $($printer.Printername) | Printer: $($printer.Printername) installed" | Tee-Object @teeParam
            $host.ui.RawUI.ForegroundColor = $t
        }

        else {
            $t = $host.ui.RawUI.ForegroundColor
            $host.ui.RawUI.ForegroundColor = "RED"
            " "                                                                                                              | Tee-Object @teeParam
            "`$(Get-logDate) | $($server) | $($printer.Printername) | Printer: $($printer.Printername) installation Failed!" | Tee-Object @teeParam
            " "                                                                                                              | Tee-Object @teeParam
            $host.ui.RawUI.ForegroundColor = $t
        }
    }
}

# notify about scipt end
"********************************************************************************************************" | Tee-Object @teeParam
" Printer installation process finished. Log file lcation stored in clipboard."                            | Tee-Object @teeParam
" `tAlways check log file: $($logPath)\$($DateFile)_prn_install_log.log"                                   | Tee-Object @teeParam
"********************************************************************************************************" | Tee-Object @teeParam
" "                                                                                                        | Tee-Object @teeParam
# try to open log file with default text viewer
Invoke-Item "$($logPath)\$($DateFile)_prn_install_log.log"
"$($logPath)\$($DateFile)_prn_install_log.log" | clip
