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
 
DECLARE @tableHTML  NVARCHAR(MAX) ;

SET @tableHTML =
    N'<H1>SQL Log Size Status</H1>' +
    N'<table border="1">' +
    N'<tr><th>DBName</th><th>FileType</th><th>CurrentSizeMB</th><th>SpaceUsedMB</th><th>FreeSpaceMB</th></tr>' +
    CAST ( ( SELECT td = DBName,		'',
					td = FileType,		'',
                    td = CAST(CurrentSizeMB AS DECIMAL(20,2)),		'',
                    td = CAST(SpaceUsedMB AS DECIMAL(20,2)),		'',
                    td = CAST(FreeSpaceMB AS DECIMAL(20,2)),		''
              FROM #FileSize
              WHERE DBName NOT IN ('distribution', 'master', 'model', 'msdb')
			GROUP BY DBName, FileType
			ORDER BY DBName, FileType DESC
              FOR XML PATH('tr'), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N'</table>' ;

EXEC msdb.dbo.sp_send_dbmail
				@profile_name = 'SQLAlertMail', --- database mail profile name
				@recipients = 'db.admin@bankmandiri.co.id',
				@Subject = 'LM_DATA: Database Growth Report',
				@body = @tableHTML,
				@body_format = 'HTML';

DROP TABLE #FileSize;
GO