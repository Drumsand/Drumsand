/*Hello there******************************************************************

.SYNOPSIS
    Dynamics AX sessions with SQL transaction information.

.DESCRIPTION
    Combines processes and transactions on SQL engine with SYSCLIENTSESSIONS 
    Dynamics AX table.

    How to use:
    Run in the context of Dynamics AX database

    To see processing requests on AX and TempDB:
    WHERE 
        db_name(ses.database_id) != N'master' WITH CTE_SessionInfo AS (
    SELECT
        ses.[status] AS [Sesh State]
        , ser.cpu_time
        , tat.name AS [tr_name]
        , AX_User = CASE 
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
    FROM sys.dm_exec_sessions AS ses
    LEFT JOIN sys.dm_exec_requests AS ser
        ON ser.session_id = ses.session_id
            OUTER APPLY sys.dm_exec_sql_text(ser.sql_handle) AS trh
    LEFT JOIN sys.dm_tran_active_snapshot_database_transactions AS ast
        ON ast.session_id = ses.session_id
    LEFT JOIN sys.dm_tran_active_transactions AS tat
        ON tat.transaction_id = ast.transaction_id
    LEFT JOIN sys.dm_db_session_space_usage AS spu
        ON spu.session_id = ses.session_id
    WHERE 
        db_name(ses.database_id) != N'master' 
        AND ses.[nt_user_name] IS NOT NULL 
)
SELECT *
FROM CTE_SessionInfo
WHERE AX_User LIKE N'SVC%'
ORDER BY blocking_session_id DESC;
        AND ser.[status] IS NOT NULL
        AND ses.[nt_user_name] IS NOT NULL 

    To see all sessions in SQL on AX and TempDB:
    WHERE 
        db_name(ses.database_id) != N'master' 
        -- AND ser.[status] IS NOT NULL
        AND ses.[nt_user_name] IS NOT NULL 
        AND spu.internal_objects_alloc_page_count IS NOT NULL
        AND spu.internal_objects_alloc_page_count != 0

.NOTES
    Subqueries 'SYSCLIENTSESSIONS AS scs' use TOP 1, ORDER BY scs.RECID DESC.
        Reason: when AX batch is cancelled manually in AX, makes AX_SESH with 
        same number, but diffrent state. Previous session is present in the 'scs'
        for brief amount of time.

.LINK
https://raw.githubusercontent.com/Drumsand
******************************************************************************/

SET
TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @useDB AS VARCHAR(24) = N'AX2012PROD.dbo.SYSCLIENTSESSIONS';
DECLARE @procDB AS VARCHAR(24) = N'AX2012PROD';
DECLARE @uName AS INT = NULL;-- NULL, 0, 1     -- "NT USER NAME"
DECLARE @qHash AS INT = NULL;-- NULL, 0, 1

SELECT [SQL_Sesh] = CASE 
        WHEN ses.[status] LIKE N'sleep%'
            THEN N' Zzzz..' -- =^..^=
        ELSE ses.[status]
        END
    , ser.command AS [CMD]
    , ser.STATUS AS [req STS]
    -- , tat.dtc_state AS [DTC State] 
    , ses.session_id AS [spid]
    , blk = CASE 
        WHEN ser.blocking_session_id IS NULL
            THEN 0
        ELSE ser.blocking_session_id
        END
        , ser.wait_time / 1000 AS [WT (s)]
    , ser.wait_type
    , app = CASE 
        WHEN ses.program_name LIKE N'%Dynamics AX'
            THEN N'AX'
        WHEN ses.program_name LIKE N'%SQL Server Management%'
            THEN N'SSMS'
        WHEN ses.program_name LIKE N'%azdata-Query%'
            THEN N'azData'
        WHEN ses.program_name LIKE N'%Microsoft® Windows® Operating System'
            THEN N'MS Win'
        WHEN ses.program_name LIKE N'vscode-mssql%'
            THEN N'VSC' -- VS Code
        WHEN ses.program_name LIKE N'%_PUB%'
            THEN N'_PUB' -- replication publication
        WHEN ses.host_name LIKE N'%CDX%'
            THEN N'AX RTS'
        WHEN ses.nt_user_name = N'SA_P_ECOM_SQL'
            THEN N'ECOM'
        WHEN ses.program_name LIKE N'%Data Provider%'
            THEN N'Core Sql'
        WHEN ses.program_name LIKE N'%SQLAgent%'
            THEN N'SQL Agent'
        WHEN ses.program_name LIKE N'Always On Operations Dashboard%'
            THEN N'AOG_Dash'
        WHEN ses.program_name LIKE N'%Profiler%'
            THEN N'Profiler'
        WHEN ses.program_name LIKE N'Repl-LogReader%'
            THEN N'r-LogReader'
        ELSE ses.program_name
        END
    -- , ast.elapsed_time_seconds as [elapsed]
    , [E.T. (s)] = CASE 
        WHEN ast.elapsed_time_seconds IS NULL
            THEN 0 -- N'_'
        ELSE (TRY_CAST(ast.elapsed_time_seconds AS NVARCHAR))
        END
    , [AX_User] = CASE 
        WHEN LEN(ses.context_info) = 0
            THEN N'N/A'
        WHEN ses.context_info IS NULL
            THEN N'None'
        ELSE (
                SELECT TOP 1
        scs.USERID
            FROM AX2012PROD.dbo.SYSCLIENTSESSIONS AS scs
            WHERE SUBSTRING(CAST(ses.context_info AS VARCHAR(128)), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2) + 1) - CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2)) = scs.SESSIONID
            ORDER BY scs.RECID DESC
                )
        END
    , [AX_SESH] = CASE 
        WHEN LEN(ses.context_info) = 0
            THEN N'_'
        WHEN ses.context_info IS NULL
            THEN N'No AXUSER'
        ELSE (SUBSTRING(CAST(ses.context_info AS VARCHAR(128)), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2) + 1) - CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2)))
        END
    , [AX_State] = CASE 
        WHEN LEN(ses.context_info) = 0
            THEN 1001
        WHEN ses.context_info IS NULL
            THEN N'_'
        ELSE (
                SELECT TOP 1
        scs.STATUS
            FROM AX2012PROD.dbo.SYSCLIENTSESSIONS AS scs
            WHERE SUBSTRING(CAST(ses.context_info AS VARCHAR(128)), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2) + 1) - CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2)) = scs.SESSIONID
            ORDER BY scs.RECID DESC
                )
        END
    , [AX_Client] = (
        SELECT TOP 1
        scs.CLIENTCOMPUTER
            FROM AX2012PROD.dbo.SYSCLIENTSESSIONS AS scs
            WHERE SUBSTRING(CAST(ses.context_info AS VARCHAR(128)), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2) + 1) - CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2)) = scs.SESSIONID
            ORDER BY scs.RECID DESC
        )
    , [AX_BATCH] = CASE 
        WHEN trh.TEXT LIKE N'%)Update BATCH%'
        AND trh.TEXT NOT LIKE N'%Hello there%'
            THEN N'# UPDATE BATCH'
        WHEN trh.TEXT LIKE N'%Hello there%'
            THEN N'# Hello'
        ELSE (
                SELECT TOP (1)
        abj.[CAPTION] AS [Batch Caption]
    FROM AX2012PROD.dbo.BATCH AS abh
        LEFT JOIN AX2012PROD.dbo.BATCHJOB AS abj
        ON abj.RECID = abh.BATCHJOBID
            AND SUBSTRING(CAST(ses.context_info AS VARCHAR(128)), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2) + 1) - CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2)) = abh.SESSIONIDX
    WHERE abj.STATUS IN (2, 3, 5, 6, 7) --( 2, 3, 5, 6, 7)
        AND abh.[STATUS] NOT IN (1, 3, 4, 5) -- test option 20230929 (issue with corect BATCH name present when not in use)
        AND ses.context_info IS NOT NULL -- test option 20230623
                )
        END
    , ses.host_name AS [HostName]
    , DB_NAME(ses.database_id) AS db_name
    , ses.nt_user_name AS [SQL user]
    -- , ser.context_info
    , (
        SELECT 'kill ' + CAST(ses.session_id AS VARCHAR(8)) + ';'
        ) AS [Thunderstruck]
    -- , CONCAT(DATEDIFF(SECOND, ses.last_request_end_time, GETDATE()), N' s') AS [prev req end]
    , DATEDIFF(SECOND, ses.last_request_end_time, GETDATE()) AS [prev req end]
    -- , CONCAT(DATEDIFF(SECOND, ses.last_request_start_time, GETDATE()), N' s') AS [last req start]
    , DATEDIFF(SECOND, ses.last_request_start_time, GETDATE()) AS [last req start]
    , CONVERT(VARCHAR, ses.login_time, 120) AS [SQL Sesh Start]
    , trh.TEXT
    , ser.query_hash
    , tat.name AS [Tx_name]
    -- , GETDATE() AS [RecTime]
    -- , [tr_isolation] = CASE ses.transaction_isolation_level
    --     WHEN 0 THEN 'Unspecified'
    --     WHEN 1 THEN 'ReadUncommitted'
    --     WHEN 2 THEN 'ReadCommitted'
    --     WHEN 3 THEN 'RepeatableRead'
    --     WHEN 4 THEN 'Serializable'
    --     WHEN 5 THEN 'Snapshot'
    --     END
    -- , [Tx STS] = CASE
    --     WHEN tat.transaction_state in (0,1) THEN 'init'
    --     WHEN tat.transaction_state = 2 THEN 'active'
    --     WHEN tat.transaction_state = 3 THEN 'read-only ended'
    --     WHEN tat.transaction_state = 4 THEN 'dtc waiting'
    --     WHEN tat.transaction_state = 5 THEN 'waiting'
    --     WHEN tat.transaction_state = 6 THEN 'comitted'
    --     WHEN tat.transaction_state = 7 THEN 'rolling back' 
    --     WHEN tat.transaction_state = 8 THEN 'rolled back'
    --         ELSE 'N/A'
    --     END
    , [Tx STS] = IIF(tat.transaction_state IN (0, 1), 'init'
        , IIF(tat.transaction_state = 2, 'active'
        , IIF(tat.transaction_state = 3, 'read-only ended'
        , IIF(tat.transaction_state = 4, 'dtc waiting'
        , IIF(tat.transaction_state = 5, 'waiting'
        , IIF(tat.transaction_state = 6, 'committed'
        , IIF(tat.transaction_state = 7, 'rolling back'
        , IIF(tat.transaction_state = 8, 'rolled back', 'N/A'
        )))))))
    )
    , ser.last_wait_type
    , ser.cpu_time
    , ser.granted_query_memory
    , spu.internal_objects_alloc_page_count
FROM sys.dm_exec_sessions AS ses
    LEFT JOIN sys.dm_exec_requests AS ser --LEFT to bring them all and in the darkness bind them
    ON ser.session_id = ses.session_id
OUTER APPLY sys.dm_exec_sql_text(ser.sql_handle) AS trh
    LEFT JOIN master.dbo.sysprocesses sys
    ON sys.spid = ses.session_id
        AND ses.context_info = sys.context_info
        AND DB_NAME(ses.database_id) = @procDB
    LEFT JOIN sys.dm_tran_active_snapshot_database_transactions AS ast
    ON ast.session_id = ses.session_id
    LEFT JOIN sys.dm_tran_active_transactions AS tat
    ON tat.transaction_id = ast.transaction_id
    LEFT JOIN sys.dm_db_session_space_usage AS spu
    ON spu.session_id = ses.session_id
WHERE 1 = 1
    AND ses.is_user_process = 1
    -- AND ser.wait_type NOT LIKE N'VDI_CLIENT_%'-- ‘by-design’ behavior where the system threads that are created for the seeding (on the primary and other replicas) will remain until the instances are rebooted, even after seeding has completed.
    -- AND NOT db_name(ses.database_id) = N'master'
    AND (@uName IS NULL OR (@uName = 1 AND ses.nt_user_name IS NOT NULL) 
        OR (@uName = 0 AND ses.nt_user_name IS NULL )) 
    AND (@qHash IS NULL OR (@qHash = 1 AND ser.query_hash IS NOT NULL) 
        OR ( @qHash = 0 AND ser.query_hash IS NULL ))
-- AND ser.cpu_time IS NOT NULL
-- AND ser.[status] IS NOT NULL             -- opened sessions without any process on them
-- AND spu.internal_objects_alloc_page_count IS NOT NULL
-- AND spu.internal_objects_alloc_page_count != 0
-- AND ses.program_name LIKE N'azdata%'dw
-- AND ses.program_name LIKE N'%SQLAgent%'
-- AND ses.host_name IN ('P-AXSQL02') --(N'P-AXBATCH01', N'P-AXAOS07') -- 
-- AND ses.session_id IN (291)
-- AND ast.transaction_id IS NOT NULL                  --
-- AND ast.elapsed_time_seconds IS NOT NULL            --
-- AND 191 = SUBSTRING(CAST(ses.context_info AS VARCHAR(128)), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2) + 1) - CHARINDEX(' ', CAST(ses.context_info AS VARCHAR(128)), 2))
-- AND ses.[status] != N'sleeping'                  -- line responsible for inactive sessions
-- AND ser.[status] IS NOT NULL                     -- line responsible for "blank" request
-- AND tat.dtc_state IS NOT NULL                    -- this responsible for DTC status filtering: https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-active-transactions-transact-sql?view=sql-server-ver16
-- AND ses.nt_user_name = N'adminkryple'
ORDER BY ser.blocking_session_id DESC
    , ast.elapsed_time_seconds DESC
    , ser.wait_time DESC
    , ses.last_request_end_time DESC
    , ses.last_request_start_time DESC --, ses.session_id DESC;
    -- ORDER BY ses.session_id DESC;
    -- ORDER BY AX_BATCH;
