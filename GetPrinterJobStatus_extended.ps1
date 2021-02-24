$PrintServer = 'KBNBSOMS11', 'KBNBSOMS12'
$PrintCheckName = "PRN_HML_ST_SH_MARK_CLR_01", "PRN_FIR_0FL_LandingArea_01", "QADASTRO_STN_P237_364e", "PRN_BRN_MP_C3002"

$Props_CurrentErrors = @{e = { $_.PSComputerName }; l = "Print Server" }, @{e = { $_.Name }; l = "Printer Name" }, "JobCount", $PrinterStatus, "Type", @{e = { $_.DriverName }; l = "Driver Name" }, "PortName", "Shared", "Published", "DeviceType"
$Props_SpoolerErrors = @{e = { $_.PSComputerName }; l = "Print Server" }, @{e = { $_.Name }; l = "Printer Name" }, @{e = { $_.jobs }; l = "Queue" }, "TotalJobsPrinted", "JobErrors"
$Props_JobErrors = @{e = { $_.PSComputerName }; l = "Print Server" }, @{e = { $_.PrinterName }; l = "Printer Name" }, "ID", "JobStatus", "UserName"
$PrintIssueFilter = "Normal", "Offline", "TonerLow", "PaperOut"

$PrinterStatus = @{
    Name       = 'PrinterStatus'
    Expression = {
        $value = $_.PrinterStatus

        switch ([int]$value) {
            1 { 'Other' }
            2 { 'Unknown' }
            3 { 'Idle' }
            4 { 'Printing' }
            5 { 'Warmup' }
            6 { 'Stopped Printing' }
            7 { 'Offline' }
            default { "$value" }
        }
    }
}

$session = New-CimSession -Comp $PrintServer -Name CheckQueue -SkipTestConnection
    $PrintCheck = Get-Printer -CimSession $session  | ? { $_.Name -in $PrintCheckName }
    $PrintJobError = ForEach ($device in $PrintCheckName) {
        Get-PrintJob -PrinterName $device -CimSession $session | ? JobStatus -match "error"
    }
    # $PrintJobError =  Get-CimInstance -ClassName Win32_PrintJob -ComputerName $PrintServer | ? { $_.Name -in $PrintCheckName -and $_.JobStatus -match "error" }
    # $PrintJobError = Get-PrintJob -CimSession $session | ? { $_.PrinterName -in $PrintCheckName -and $_.JobStatus -match "error" }
    $PrintIssue = Get-Printer -CimSession $session  | ? { $_.PrinterStatus -notin $PrintIssueFilter } # try -in
    $PrintTotal = Get-CimInstance -ClassName Win32_PerfFormattedData_Spooler_PrintQueue -CimSession $session | Where-Object { $_.jobs -gt 0 -or $_.JobErrors -gt 0 }
Remove-CimSession $session

Write-Host "`n Current errors in printer jobs for queried printers `n" -ForegroundColor Black -BackgroundColor White
$PrintCheck | Select $Props_CurrentErrors | Sort "Printer Name", "Print Server" | FT -auto

Write-Host "`n Job errors on queried printers driver - additional data not visible in print server console `n" -ForegroundColor Black -BackgroundColor White
$PrintJobError | Select $Props_JobErrors | Sort "Printer Name", "Print Server"| FT -auto

Write-Host "`n Total number of printer malfunctions on queried print servers `n" -ForegroundColor Black -BackgroundColor White
$PrintIssue | Select $Props_CurrentErrors | Sort "Printer Name", "Print Server" | FT -auto

Write-Host "`n Total number of errors on queried print servers `n" -ForegroundColor Black -BackgroundColor White
$PrintTotal | Select $Props_SpoolerErrors | Sort -Desc Queue, "Print Server" | FT -auto
