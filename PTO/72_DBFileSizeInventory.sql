DECLARE @sql    NVARCHAR(MAX);
DECLARE @dbname SYSNAME;

/* ================================================================
   1. POPULATE DATABASE FILE INVENTORY
   ================================================================ */
IF OBJECT_ID('tempdb..#FileInventory') IS NOT NULL DROP TABLE #FileInventory;
IF OBJECT_ID('tempdb..#Skipped')       IS NOT NULL DROP TABLE #Skipped;

CREATE TABLE #FileInventory
(
    DatabaseName              SYSNAME,
    DatabaseState             NVARCHAR(60),
    RecoveryModel             NVARCHAR(60),
    FilegroupName             SYSNAME NULL,
    FilegroupType             NVARCHAR(60) NULL,
    LogicalFileName           SYSNAME,
    FileType                  NVARCHAR(60),
    PhysicalPath              NVARCHAR(260),
    IsPrimaryFilestreamFile   INT NULL,
    SizeMB                    DECIMAL(18,2),
    UsedMB                    DECIMAL(18,2) NULL,
    Growth                    VARCHAR(20),
    MaxSize                   VARCHAR(20),
    FileState                 NVARCHAR(60)
);

CREATE TABLE #Skipped
(
    DatabaseName SYSNAME,
    Reason       NVARCHAR(4000)
);

/* Databases that cannot be inventoried are recorded, not silently dropped. */
INSERT INTO #Skipped (DatabaseName, Reason)
SELECT d.name,
       CASE WHEN d.state_desc <> 'ONLINE' THEN d.state_desc
            ELSE 'NOT ACCESSIBLE' END
FROM sys.databases AS d
WHERE d.database_id > 4
  AND (d.state_desc <> 'ONLINE' OR HAS_DBACCESS(d.name) = 0);

DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT d.name
    FROM sys.databases AS d
    WHERE d.database_id > 4          -- exclude system databases
      AND d.state_desc = 'ONLINE'
      AND HAS_DBACCESS(d.name) = 1
    ORDER BY d.name;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @dbname;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
    USE ' + QUOTENAME(@dbname) + N';

    INSERT INTO #FileInventory
    SELECT
        DB_NAME() AS DatabaseName,
        d.state_desc AS DatabaseState,
        d.recovery_model_desc AS RecoveryModel,
        fg.name AS FilegroupName,
        fg.type_desc AS FilegroupType,
        mf.name AS LogicalFileName,
        mf.type_desc AS FileType,
        mf.physical_name AS PhysicalPath,
        CASE
            WHEN mf.type_desc = ''FILESTREAM''
                THEN CAST(FILEPROPERTY(mf.name, ''IsPrimaryFile'') AS INT)
            ELSE NULL
        END AS IsPrimaryFilestreamFile,
        CAST(mf.size * 8.0 / 1024 AS DECIMAL(18,2)) AS SizeMB,
        CASE
            WHEN mf.type_desc = ''FILESTREAM'' THEN NULL
            ELSE CAST(FILEPROPERTY(mf.name, ''SpaceUsed'') * 8.0 / 1024 AS DECIMAL(18,2))
        END AS UsedMB,
        CASE
            WHEN mf.is_percent_growth = 1
                THEN CAST(mf.growth AS VARCHAR(10)) + ''%''
            ELSE CAST(mf.growth * 8.0 / 1024 AS VARCHAR(20)) + '' MB''
        END AS Growth,
        CASE
            WHEN mf.max_size = -1 THEN ''Unlimited''
            WHEN mf.max_size = 268435456 THEN ''Unlimited (Log)''
            ELSE CAST(mf.max_size * 8.0 / 1024 AS VARCHAR(20)) + '' MB''
        END AS MaxSize,
        mf.state_desc AS FileState
    FROM sys.database_files AS mf
    LEFT JOIN sys.filegroups AS fg
        ON mf.data_space_id = fg.data_space_id
    CROSS JOIN sys.databases AS d
    WHERE d.name = DB_NAME();
    ';

    BEGIN TRY
        EXEC sys.sp_executesql @sql;
    END TRY
    BEGIN CATCH
        INSERT INTO #Skipped (DatabaseName, Reason) VALUES (@dbname, ERROR_MESSAGE());
    END CATCH;

    FETCH NEXT FROM db_cursor INTO @dbname;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

/* ================================================================
   2. DISPLAY DATABASE-LEVEL INVENTORY (largest database first)
   ================================================================ */

WITH db AS
(SELECT DatabaseName, DatabaseState AS Status, RecoveryModel, 
       DBSizeMB = SUM(SizeMB), 
       DataSizeMB = (SELECT SUM(b.SizeMB) FROM #FileInventory b WHERE b.DatabaseName = a.DatabaseName AND b.FileType = 'ROWS'),
       DataUsedMB = (SELECT SUM(c.UsedMB) FROM #FileInventory c WHERE c.DatabaseName = a.DatabaseName AND c.FileType = 'ROWS'),
       LogSizeMB = (SELECT SUM(d.SizeMB) FROM #FileInventory d WHERE d.DatabaseName = a.DatabaseName AND d.FileType = 'LOG'),
       LogUsedMB = (SELECT SUM(e.UsedMB) FROM #FileInventory e WHERE e.DatabaseName = a.DatabaseName AND e.FileType = 'LOG')
FROM #FileInventory a
GROUP BY DatabaseName, DatabaseState, RecoveryModel)
SELECT DatabaseName, Status, RecoveryModel, DBSizeMB, DataSizeMB, DataUsedMB,
       DataUsedPct = CASE WHEN DataUsedMB IS NOT NULL AND DataSizeMB > 0 THEN CAST(DataUsedMB * 100.0 / DataSizeMB AS DECIMAL(5,2)) END,
       LogSizeMB, LogUsedMB,
       LogUsedPct = CASE WHEN LogUsedMB IS NOT NULL AND LogSizeMB > 0 THEN CAST(LogUsedMB * 100.0 / LogSizeMB AS DECIMAL(5,2)) END
FROM db
UNION ALL
SELECT DatabaseName, Reason AS Status, NULL AS RecoveryModel, NULL, NULL, NULL,
       NULL, NULL, NULL, NULL
FROM #Skipped
ORDER BY DBSizeMB DESC;

/* ================================================================
   3. DISPLAY FILE-LEVEL INVENTORY (largest database first)
   ================================================================ */

;WITH r AS
(
    SELECT fi.*,
           DBSizeMB = SUM(fi.SizeMB) OVER (PARTITION BY fi.DatabaseName),
           UsedPct  = CASE WHEN fi.UsedMB IS NOT NULL AND fi.SizeMB > 0
                           THEN CAST(fi.UsedMB * 100.0 / fi.SizeMB AS DECIMAL(5,2)) END
    FROM #FileInventory AS fi
)
SELECT DatabaseName, DatabaseState AS Status, RecoveryModel, DBSizeMB,
       FileGroupName, LogicalFileName, FileType, PhysicalPath, SizeMB, UsedMB, UsedPct
FROM r
ORDER BY DBSizeMB DESC;