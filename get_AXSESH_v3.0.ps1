#---------------------------------------------------------------
# Script Parameters & Configuration
#---------------------------------------------------------------
$ErrorActionPreference = "Stop"
$CPUlvlLow      = 1
$sqlQTimeout    = 60
#$filterState   = 3  # Update this to match the desired AX_State value
$sqlSrv         = "P-AXSQL01"
$procDB         = "AX2012PROD"
$logDB          = "DBA_ADMIN"
$logTable       = "dbo.teSeshLog"   # Log table (format: schema.TableName)

# Filtering parameters: 
# Set to 1 for non-null, 0 for null, or $null for all
$uName = $null  
$qHash = $null

#---------------------------------------------------------------
# SQL Server Connection Parameter Setup
#---------------------------------------------------------------
$defaultSQLConnParam = @{
    ServerInstance         = $sqlSrv
    Database               = $null
    QueryTimeout           = $sqlQTimeout
    ApplicationIntent      = "ReadOnly"
    Query                  = $null
    TrustServerCertificate = $true
    AbortOnError           = $true
    IncludeSqlUserErrors   = $true
    OutputSqlErrors        = $true
    Verbose                = $true
}

# Connection parameters for different operations
$AXSESHStatus = $defaultSQLConnParam.Clone()
$AXSESHStatus['Database'] = $procDB

$AXTeSeshLog = $defaultSQLConnParam.Clone()
$AXTeSeshLog['Database'] = $logDB
$AXTeSeshLog['ApplicationIntent'] = "ReadWrite"

$sqlKillParams = $defaultSQLConnParam.Clone()
$sqlKillParams['Database'] = $procDB

#---------------------------------------------------------------
# SQL Query Definition
#---------------------------------------------------------------
$sqlQuery = @"
DECLARE @uName INT = $(if ($null -ne $uName) { $uName } else { 'NULL' });
DECLARE @qHash INT = $(if ($null -ne $qHash) { $qHash } else { 'NULL' });
SELECT
    GETDATE() AS [RecTime]
    , [SQL_Sesh_State] = CASE 
        WHEN ses.status LIKE N'sleep%' THEN N' Zzzz..' 
        ELSE ses.status 
    END
    , ses.session_id AS [spid]
    , blk = CASE 
        WHEN ser.blocking_session_id IS NULL THEN 0 
        ELSE ser.blocking_session_id 
    END
    , ser.cpu_time AS [reg_CPU_time]
    , [Tx_STS] = CASE
        WHEN tat.transaction_state IN (0,1) THEN 'init'
        WHEN tat.transaction_state = 2 THEN 'active'
        WHEN tat.transaction_state = 3 THEN 'read-only ended'
        WHEN tat.transaction_state = 4 THEN 'dtc waiting'
        WHEN tat.transaction_state = 6 THEN 'comitted'
        WHEN tat.transaction_state = 7 THEN 'rolling back'
        WHEN tat.transaction_state = 8 THEN 'rolled back'
        ELSE 'N/A'
    END
    , ser.[status] AS [req_STS]
    , ses.host_name AS [HostName]
    , [app] = CASE
        WHEN ses.program_name LIKE N'%Dynamics AX' THEN N'AX'
        WHEN ses.program_name LIKE N'%SQL Server Management%' THEN N'SSMS'
        WHEN ses.program_name LIKE N'%azdata-Query%' THEN N'azData'
        WHEN ses.program_name LIKE N'%MicrosoftÂ® WindowsÂ® Operating System' THEN N'MS Win'
        WHEN ses.program_name LIKE N'vscode-mssql%' THEN N'VSC'
        WHEN ses.program_name LIKE N'%_PUB%' THEN N'_PUB'
        WHEN ses.host_name LIKE N'%CDX%' THEN N'AX RTS'
        WHEN ses.nt_user_name = N'SA_P_ECOM_SQL' THEN N'ECOM'
        WHEN ses.program_name LIKE N'%Data Provider%' THEN N'Core Sql'
        WHEN ses.program_name LIKE N'%SQLAgent%' THEN N'SQL Agent'
        WHEN ses.program_name LIKE N'Always On Operations Dashboard%' THEN N'AOG_Dash'
        ELSE ses.program_name
    END
    , [ELAPSED] = CASE 
        WHEN ast.elapsed_time_seconds IS NULL THEN 0 
        ELSE ast.elapsed_time_seconds 
    END
    , [AX_User] = CASE 
        WHEN LEN(ses.context_info) = 0 THEN N'N/A'
        WHEN ses.context_info IS NULL THEN N'None'
            ELSE (
                SELECT TOP 1 scs.USERID
                FROM AX2012PROD.dbo.SYSCLIENTSESSIONS AS scs
                WHERE SUBSTRING(CAST(ses.context_info AS VARCHAR(128)),
                        CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),2),
                        CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),
                        CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),2) + 1) - CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),2)) = scs.SESSIONID
                ORDER BY scs.RECID DESC
            )
        END
    , [AX_SESH] = CASE
        WHEN LEN(ses.context_info) = 0 THEN N'_'
        WHEN ses.context_info IS NULL THEN N'No AXUSER'
            ELSE (SUBSTRING(CAST(ses.context_info AS VARCHAR(128)),
                CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),2),
                CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),
                CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),2) + 1) - CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),2))
            )
        END
    , [AX_State] = CASE
        WHEN LEN(ses.context_info) = 0 THEN 1001
        WHEN ses.context_info IS NULL THEN N'_'
            ELSE (
                    SELECT TOP 1 scs.STATUS
                    FROM AX2012PROD.dbo.SYSCLIENTSESSIONS AS scs
                    WHERE SUBSTRING(CAST(ses.context_info AS VARCHAR(128)),
                        CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),2),
                        CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),
                        CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),2) + 1) - CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),2)) = scs.SESSIONID
                    ORDER BY scs.RECID DESC
            )
    END
    , [AX_BATCH] = CASE
    WHEN trh.text LIKE N'%)Update BATCH%' AND trh.text NOT LIKE N'%Hello there%' THEN N'# UPDATE BATCH'
    WHEN trh.text LIKE N'%Hello there%' THEN N'# Hello'
        ELSE (
            SELECT TOP (1)
                abj.[CAPTION] AS [Batch Caption]
            FROM AX2012PROD.dbo.BATCH AS abh
            LEFT JOIN AX2012PROD.dbo.BATCHJOB AS abj
                ON abj.RECID = abh.BATCHJOBID
                AND SUBSTRING(CAST(ses.context_info AS VARCHAR(128)),
                    CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),2),
                    CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),
                    CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),2) + 1) - CHARINDEX(' ',CAST(ses.context_info AS VARCHAR(128)),2)) = abh.SESSIONIDX
            WHERE 
                abj.STATUS IN ( 2, 3, 5, 6, 7) --( 2, 3, 5, 6, 7)
                    AND abh.[STATUS] NOT IN (1, 3, 4, 5)   -- test option 20230929 (issue with corect BATCH name present when not in use)
                    AND ses.context_info IS NOT NULL  -- test option 20230623
        )
    END
    , ses.nt_user_name AS [SQL_User]
    , ser.wait_time / 1000 AS [WaitTime]
    , ser.wait_type AS [WaitType]
    , sys.lastwaittype AS [LastWaitType]
    , N'0x' + CONVERT(NVARCHAR(32), ser.query_hash, 2) AS [query_hash]
    , DATEDIFF(SECOND, ses.last_request_end_time, GETDATE()) AS [prevReqEnd]
    , DATEDIFF(SECOND, ses.last_request_start_time, GETDATE()) AS [lastReqStart]
    , CONVERT(VARCHAR, ses.login_time, 120) AS [SQL_Sesh_Start]
FROM sys.dm_exec_sessions AS ses
LEFT JOIN sys.dm_exec_requests AS ser
    ON ser.session_id = ses.session_id
        OUTER APPLY sys.dm_exec_sql_text(ser.sql_handle) AS trh
JOIN sys.sysprocesses sys
    ON sys.spid = ses.session_id
LEFT JOIN sys.dm_tran_active_snapshot_database_transactions AS ast
    ON ast.session_id = ses.session_id
LEFT JOIN sys.dm_tran_active_transactions AS tat
    ON tat.transaction_id = ast.transaction_id
LEFT JOIN sys.dm_db_session_space_usage AS spu
    ON spu.session_id = ses.session_id
WHERE 1 = 1
    AND ses.is_user_process = 1
    AND ( @uName IS NULL OR ( @uName = 1 AND ses.nt_user_name IS NOT NULL ) OR ( @uName = 0 AND ses.nt_user_name IS NULL ) )
    AND ( @qHash IS NULL OR ( @qHash = 1 AND ser.query_hash IS NOT NULL ) OR ( @qHash = 0 AND ser.query_hash IS NULL ) )
ORDER BY ser.blocking_session_id DESC
    , ses.last_request_end_time DESC
    , ses.last_request_start_time DESC
    , ses.session_id DESC;
"@

#---------------------------------------------------------------
# Helper Functions
#---------------------------------------------------------------

# Returns a formatted date string for logging
function Get-logDate {
    Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

# Get core usage statistics as an array of objects
function Get-CoresUsage {
    if ($PSVersionTable.PSVersion.Major -le 5) {
        $res = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor |
               Select-Object Name, PercentProcessorTime
    }
    else {
        $res = Get-CimInstance -Query "Select Name, PercentProcessorTime from Win32_PerfFormattedData_PerfOS_Processor"
    }
    $coreUsageArray = @()
    foreach ($single in $res) {
        $coreUsageArray += [PSCustomObject]@{
            TimeStamp  = Get-logDate
            ServerName = $env:COMPUTERNAME
            UsageValue = $single.PercentProcessorTime
            CoreName   = $single.Name
        }
    }
    return $coreUsageArray
}

# Function to loop thtough filtered SQL sessions and kill them in SQL Server
function Get-RidOF {
    param (
        [Parameter(Mandatory=$true)]
        [array]$sqlSessions
    )
    foreach ($sqlSession in $sqlSessions) {
        $killQuery = "KILL $($sqlSession.spid)"
        Write-Output "Executing query: $killQuery"
        $sqlKillParams['Query'] = $killQuery
        try {
            Invoke-SqlCmd @sqlKillParams -ErrorAction Stop
            Write-Output "Killed session with SPID: $($sqlSession.spid)"
        } catch {
            Write-Output "Failed to kill session with SPID: $($sqlSession.spid). Error: $_"
        }
    }
}

# Ensure the log table exists in the target database
function Get-EnsureTableExists {
    param (
        [string]$logTable = $script:logTable,  # Uses existing script-level variable
        [hashtable]$AXTeSeshLog = $script:AXTeSeshLog  # Uses existing script-level variable
    )

    $tableNameOnly = $logTable.Split('.')[1]

    $checkTableQuery = @"
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = '$tableNameOnly')
BEGIN
    CREATE TABLE $logTable (
        RecTime DATETIME,
        removed BIT DEFAULT 0,
        SQL_Sesh_State NVARCHAR(50),
        spid INT,
        blk INT,
        reg_CPU_time INT,
        Tx_STS NVARCHAR(50),
        req_STS NVARCHAR(50),
        HostName NVARCHAR(128),
        app NVARCHAR(128),
        ELAPSED INT,
        AX_User NVARCHAR(50),
        AX_SESH NVARCHAR(50),
        AX_State INT,
        AX_BATCH NVARCHAR(128),
        SQL_User NVARCHAR(128),
        WaitTime INT,
        WaitType NVARCHAR(60),
        LastWaitType NVARCHAR(60),
        query_hash NVARCHAR(64),
        prevReqEnd INT,
        lastReqStart INT,
        SQL_Sesh_Start DATETIME,
        CPU_Usage INT
    )
END
"@
    $AXTeSeshLog['Query'] = $checkTableQuery
    Invoke-SqlCmd @AXTeSeshLog
}


# Helper function to convert DBNull values to $null
function Convert-DbNullToNull {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Object
    )
    foreach ($prop in $Object.PSObject.Properties) {
        if ($Object.$($prop.Name) -is [System.DBNull]) {
            $Object.$($prop.Name) = $null
        }
    }
    return $Object
}

# Bulk insert data using Write-SqlTableData, after cleaning DBNull values
function Get-InsertData {
    param (
        [Parameter(Mandatory = $true)]
        [array]$DataRows,
        [Parameter(Mandatory = $true)]
        [string]$logTable
    )
    if ($DataRows.Count -gt 0) {
        # Convert any DBNull values to $null
        $cleanData = $DataRows | ForEach-Object { Convert-DbNullToNull $_ }
        
        Write-SqlTableData -ServerInstance $sqlSrv -Database $logDB -SchemaName "dbo" -TableName ($logTable.Split('.')[1]) ` -InputData $cleanData
    }
}

#---------------------------------------------------------------
# Main Execution Flow
#---------------------------------------------------------------

# 1. Ensure the log table exists
Get-EnsureTableExists

# 2. Check total CPU usage
$coresUsage = Get-CoresUsage
$coresUsageTotal = ($coresUsage | Where-Object { $_.CoreName -eq "_Total" }).UsageValue
Write-Output "Total CPU Usage: $coresUsageTotal"

# 3. Execute SQL query to retrieve session data and build an array of objects
#
# Ensure the Query key in @AXSESHStatus is assigned before execution
$AXSESHStatus['Query'] = $sqlQuery

$sqlSessions = Invoke-SqlCmd @AXSESHStatus | ForEach-Object {
    [PSCustomObject]@{
        RecTime        = $_.RecTime
        removed        = 1  # Explicitly set to 1 to stare that sessions were removed.
        SQL_Sesh_State = $_.SQL_Sesh_State
        spid           = $_.spid
        blk            = $_.blk
        reg_CPU_time   = $_.reg_CPU_time
        Tx_STS         = $_.Tx_STS
        req_STS        = $_.req_STS
        HostName       = $_.HostName
        app            = $_.app
        ELAPSED        = $_.ELAPSED
        AX_User        = if ($null -eq $_.AX_User) { "N/A" } else { $_.AX_User }
        AX_SESH        = if ($null -eq $_.AX_SESH) { "_" } else { $_.AX_SESH }
        AX_State       = if ($null -eq $_.AX_State) { 0 } else { $_.AX_State }
        AX_BATCH       = if ($null -eq $_.AX_BATCH) { "N/A" } else { $_.AX_BATCH }
        SQL_User       = $_.SQL_User
        WaitTime       = $_.WaitTime
        WaitType       = $_.WaitType
        LastWaitType   = $_.LastWaitType
        query_hash     = $_.query_hash
        prevReqEnd     = $_.prevReqEnd
        lastReqStart   = $_.lastReqStart
        SQL_Sesh_Start = $_.SQL_Sesh_Start
        CPU_Usage      = $coresUsageTotal
    }
} | Where-Object { 
        $_.AX_State -eq $filterState -or
        ( $_.AX_BATCH -match "SendGrid" -and $_.ELAPSED -gt 420 ) -or
        ( $_.AX_BATCH -like "RET_*" -and $_.ELAPSED -gt 1800 ) -or 
        # ( $_.AX_BATCH -like "*" -and $_.ELAPSED -gt 2 )  
        ( $_.SQL_User -eq "adminkryple" -and $_.ELAPSED -gt 1 )       #For testing purposes
}

# 4. Bulk insert session data if available; otherwise, log only CPU usage
if ($sqlSessions -and $sqlSessions.Count -gt 0) {
    # Wait for Get-RidOF
}
else {
    $logData = [PSCustomObject]@{
        RecTime        = Get-logDate
        removed        = 0  # Explicitly set to 0 for bit column
        SQL_Sesh_State = $null
        spid           = $null
        blk            = $null
        reg_CPU_time   = $null
        Tx_STS         = $null
        req_STS        = $null
        HostName       = $null
        app            = $null
        ELAPSED        = $null
        AX_User        = $null
        AX_SESH        = $null
        AX_State       = $null
        AX_BATCH       = $null
        SQL_User       = $null
        WaitTime       = $null
        WaitType       = $null
        LastWaitType   = $null
        query_hash     = $null
        prevReqEnd     = $null
        lastReqStart   = $null
        SQL_Sesh_Start = $null
        CPU_Usage      = $coresUsageTotal
    }
    Get-InsertData -DataRows @($logData) -logTable $logTable
}

# 5. Kill sessions if CPU usage is high
if ($coresUsageTotal -gt $CPUlvlLow) {
    if ($sqlSessions -and $sqlSessions.Count -gt 0) {
        Write-Output "Sessions to be killed and marked as removed: $($sqlSessions.Count)"
        Get-RidOF -sqlSessions $sqlSessions
        Get-InsertData -DataRows $sqlSessions -logTable $logTable
    }
    else {
        Write-Output "No sessions to update. `$filteredSessions is null or empty."
    }
}