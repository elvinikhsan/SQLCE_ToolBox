SET NOCOUNT ON;
SET XACT_ABORT ON;

CREATE TABLE #FileSize
(DBName SYSNAME, 
    FileName SYSNAME, 
    FileType SYSNAME,
    CurrentSizeMB DECIMAL(18,2), 
	SpaceUsedMB DECIMAL(18,2),
    FreeSpaceMB DECIMAL(18,2)
);
    
INSERT INTO #FileSize(dbName, FileName, FileType, CurrentSizeMB, SpaceUsedMB, FreeSpaceMB)
EXEC sp_msforeachdb 
'USE [?]; 
 SELECT DB_NAME() AS DbName, 
        name AS FileName, 
        type_desc,
        size/128.0 AS CurrentSizeMB,  
		CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT)/128.0 AS UsedSpaceMB,
        size/128.0 - CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT)/128.0 AS FreeSpaceMB
FROM sys.database_files
WHERE type IN (0,1);';
    
SELECT DBName, FileType, SUM(CurrentSizeMB) AS CurrentSizeMB, SUM(SpaceUsedMB) AS SpaceUsedMB, SUM(FreeSpaceMB) AS FreeSpaceMB
FROM #FileSize
WHERE DBName NOT IN ('distribution', 'master', 'model', 'msdb')
GROUP BY DBName, FileType
ORDER BY DBName, FileType DESC;
    
DROP TABLE #FileSize;
GO