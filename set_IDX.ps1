$sql01 = @'
IF NOT EXISTS(SELECT * FROM sys.indexes WHERE name = '
'@

$IDXName = "CHA_Q1_INVENTSUM_PERF01"

$sql02 = @'
' AND object_id = OBJECT_ID('
'@

$tblName = "INVENTSUM"

$sql03 = @'
')) 
BEGIN
CREATE NONCLUSTERED INDEX [
'@

$IDXName = "CHA_Q1_INVENTSUM_PERF01"

$sql04 = @'
] ON [dbo].[
'@

$tblName = "INVENTSUM"

$sql05 = @'
]
(
[ITEMID] ASC, [RECID] ASC, [INVENTDIMID] ASC, [RESERVPHYSICAL] ASC, [PARTITION] ASC, [DATAAREAID] ASC, [CLOSED] ASC
)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY];
END
'@

$sql = $sql01 + $IDXName + $sql02 + $tblName + $sql03 + $IDXName + $sql04 + $tblName + $sql05
$sql | Write-Output