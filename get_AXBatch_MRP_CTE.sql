/* 
-- ================================================
-- Script Name: DAX MRP Thread
-- File Name  : get_AXBatch_MRP_CTE.sql
-- Description:	Shows running MRP Threads states with details
--
-- Parameters In: none
-- Parameter Out: MRP Threads and states
-- 
-- Databases Effected: none, SELECT only
-- Tables Effected: SELECT FROM [dbo].[REQCALCTASKSBUNDLE]
-- 
-- Additional Notes: CTE for PARTITION BY [PROCESSID], [STATUS], [LEVELSTATE]
--    Threads running time and state returned
--
-- ================================================
-- ================================================
-- Author: DrumSand
-- Creation Date: 2023.02
-- Git: https://raw.githubusercontent.com/Drumsand/Drumsand/master/get_AXBatch_MRP_CTE.sql
-- Modified Date: 2023.11.14
-- Version 1.2
-- ================================================
*/

WITH CTE
AS (
    SELECT 
        -- [LEVEL_]
        [LEVELSTATE]
        , [PROCESSDATAAREAID]
        , [PROCESSID]
        , [PROCESSINGSTATE]
        , [STARTTIME]
        , [ENDTIME]
        , [STATUS]
        , [THREADID]
        , ROW_NUMBER() OVER (
            PARTITION BY [PROCESSID], [STATUS], [LEVELSTATE] ORDER BY [PROCESSID], [LEVELSTATE] DESC
            ) AS [ROWNUM]
    FROM [dbo].[REQCALCTASKSBUNDLE]
    )
SELECT
    [LEVELSTATE]
    , [PROCESSDATAAREAID] AS [AX Unit]
    , [PROCESSID]
    , [PROCESSINGSTATE] AS [STATE]
    -- , [STARTTIME]
    -- , [ENDTIME]
    , [Scheduler Start (+2h)] = CASE 
        WHEN [STARTTIME] LIKE N'%1900%'
            AND LEVELSTATE = 0
            THEN N' _Not Started!!'
        WHEN [STARTTIME] LIKE N'%1900%'
            AND LEVELSTATE BETWEEN 10 AND 50
            THEN N' _Initiating' + N' ' + (CONVERT(NVARCHAR(2), [LEVELSTATE])) + N' ' + N'LVL'
        ELSE (CONVERT(CHAR(16), DATEADD(HOUR, 1, [STARTTIME]), 20))
        END
    , [From Start (min)] = CASE 
        WHEN DATEDIFF(MINUTE, [STARTTIME], [ENDTIME]) < 0
            THEN N' _Running'
        ELSE CONVERT(NCHAR(16), DATEDIFF(MINUTE, [STARTTIME], [ENDTIME]))
        END
    , [Thread running (min)] = CASE 
        WHEN DATEDIFF(MINUTE, [STARTTIME], [ENDTIME]) < 0
            AND LEVELSTATE IN (0, 1)
            THEN CONVERT(CHAR(16), DATEDIFF(MINUTE, [STARTTIME], GETDATE()))
        WHEN DATEDIFF(MINUTE, [STARTTIME], [ENDTIME]) < 0 --AND LEVELSTATE = 50
            THEN N' _Initiating'
        ELSE CONVERT(CHAR(16), DATEDIFF(MINUTE, [STARTTIME], [ENDTIME]))
        END
    , [End Time (+2h)] = CASE 
        WHEN CONVERT(CHAR(16), DATEADD(HOUR, 1, [ENDTIME]), 20) LIKE N'1900%'
            THEN N'_Not Ended!'
        ELSE (CONVERT(CHAR(16), DATEADD(HOUR, 1, [ENDTIME]), 20))
        END
    , [STATUS]
    , [ROWNUM]
FROM CTE
WHERE [ROWNUM] IN (1)
GROUP BY
    [LEVELSTATE]
    , [PROCESSID]
    , [PROCESSDATAAREAID]
    , [PROCESSINGSTATE]
    , [STARTTIME]
    , [ENDTIME]
    , [STATUS]
    , [THREADID]
    , [ROWNUM]
ORDER BY PROCESSID
    , STATUS DESC;
