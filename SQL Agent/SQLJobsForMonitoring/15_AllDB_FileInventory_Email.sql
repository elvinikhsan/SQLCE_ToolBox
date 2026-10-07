/*
    15_AllDB_FileInventory_Email.sql

    Purpose:
      Inventory every data/log/FILESTREAM file for ALL user databases on this
      instance (system databases excluded) and send two HTML emails:
        Email 1 - file-level inventory, largest database first
        Email 2 - allocation aggregated by file type and drive letter

      Derived from 01_Wave_DB_FileInventory.sql. The wave text-file input,
      BULK INSERT logic and the validation result set (result set 3) are removed.

    Highlighting (Email 1):
      - Used %  >= 90            : red background
      - Used %  >= 75 and < 90   : yellow background
      - Size (MB) vs SQL Server file size limit (16 TB data / 2 TB log):
          >= 90%            : bold text, red background
          >= 75% and < 90%  : bold text, yellow background
      FILESTREAM containers have no used/allocated ratio and no per-file
      size limit, so they are never highlighted.

    Requirements:
      - Database Mail configured; @MailProfile must exist in msdb.
      - Run as a login that can access every user database (sysadmin / SQL
        Agent service account). Databases that are not ONLINE or not
        accessible (e.g. RESTORING, non-readable AG secondary) are skipped
        and listed at the bottom of Email 1.
*/

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

/* ================================================================
   1. CONFIGURATION
   ================================================================ */
DECLARE @MailProfile  SYSNAME       = N'<DatabaseMailProfile>';
DECLARE @Recipients   NVARCHAR(MAX) = N'<Recipients>';   -- semicolon-separated

DECLARE @WarnPct      DECIMAL(5,2)  = 75.00;     -- Used % yellow from
DECLARE @CritPct      DECIMAL(5,2)  = 90.00;     -- Used % red from
DECLARE @LimitWarnPct DECIMAL(5,2)  = 75.00;     -- % of file size limit, yellow from
DECLARE @LimitPct     DECIMAL(5,2)  = 90.00;     -- % of file size limit, red from
DECLARE @DataLimitMB  DECIMAL(18,2) = 16777216;  -- 16 TB data file limit
DECLARE @LogLimitMB   DECIMAL(18,2) = 2097152;   -- 2 TB log file limit

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysmail_profile WHERE name = @MailProfile)
BEGIN
    ;THROW 50001, 'Database Mail profile in @MailProfile does not exist.', 1;
END;

DECLARE @sql    NVARCHAR(MAX);
DECLARE @dbname SYSNAME;

/* ================================================================
   2. DATABASE FILE INVENTORY
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
   3. HTML STYLES (inline - Outlook ignores most <style> rules)
   ================================================================ */
DECLARE @Font   NVARCHAR(200) = N'font-family:''Segoe UI'',Arial,sans-serif;font-size:9pt;';
DECLARE @Th     NVARCHAR(400) = @Font + N'background:#0078D4;color:#FFFFFF;font-weight:600;padding:4px 6px;border:1px solid #005A9E;text-align:left;white-space:nowrap;';
DECLARE @Td     NVARCHAR(400) = @Font + N'padding:3px 6px;border:1px solid #D9D9D9;white-space:nowrap;';
DECLARE @Num    NVARCHAR(50)  = N'text-align:right;';
DECLARE @BandA  NVARCHAR(50)  = N'background:#FFFFFF;';
DECLARE @BandB  NVARCHAR(50)  = N'background:#EAF3FB;';
DECLARE @Red    NVARCHAR(50)  = N'background:#FF5B5B;';
DECLARE @Yellow NVARCHAR(50)  = N'background:#FFE666;';
DECLARE @Bold   NVARCHAR(50)  = N'font-weight:700;';

DECLARE @Server    NVARCHAR(200) = CAST(@@SERVERNAME AS NVARCHAR(200));
DECLARE @RunTime   NVARCHAR(30)  = CONVERT(NVARCHAR(30), SYSDATETIME(), 120);
DECLARE @Subject   NVARCHAR(255);
DECLARE @Body      NVARCHAR(MAX);
DECLARE @Rows      NVARCHAR(MAX);
DECLARE @Summary   NVARCHAR(MAX);
DECLARE @SkipHtml  NVARCHAR(MAX);

/* ================================================================
   4. EMAIL 1 - FILE-LEVEL INVENTORY (largest database first)
   ================================================================ */
;WITH r AS
(
    SELECT fi.*,
           DbSizeMB = SUM(fi.SizeMB) OVER (PARTITION BY fi.DatabaseName),
           UsedPct  = CASE WHEN fi.UsedMB IS NOT NULL AND fi.SizeMB > 0
                           THEN CAST(fi.UsedMB * 100.0 / fi.SizeMB AS DECIMAL(5,2)) END,
           LimitMB  = CASE fi.FileType WHEN 'ROWS' THEN @DataLimitMB
                                       WHEN 'LOG'  THEN @LogLimitMB END
    FROM #FileInventory AS fi
),
s AS
(
    SELECT r.*,
           rn = ROW_NUMBER() OVER (ORDER BY r.DbSizeMB DESC, r.DatabaseName,
                                   CASE r.FileType WHEN 'ROWS' THEN 1 WHEN 'LOG' THEN 2 ELSE 3 END,
                                   r.LogicalFileName)
    FROM r
),
c AS
(
    SELECT s.*,
           Band     = CASE WHEN s.rn % 2 = 0 THEN @BandB ELSE @BandA END,
           PctStyle = CASE WHEN s.UsedPct >= @CritPct THEN @Red
                           WHEN s.UsedPct >= @WarnPct THEN @Yellow
                           ELSE CASE WHEN s.rn % 2 = 0 THEN @BandB ELSE @BandA END END,
           SizeStyle = CASE WHEN s.LimitMB IS NOT NULL AND s.SizeMB >= s.LimitMB * @LimitPct / 100.0
                            THEN @Red + @Bold
                            WHEN s.LimitMB IS NOT NULL AND s.SizeMB >= s.LimitMB * @LimitWarnPct / 100.0
                            THEN @Yellow + @Bold
                            ELSE CASE WHEN s.rn % 2 = 0 THEN @BandB ELSE @BandA END END
    FROM s
)
SELECT @Rows = STRING_AGG(CAST(
        N'<tr>'
      + N'<td style="' + @Td + Band + N'">' + REPLACE(REPLACE(REPLACE(DatabaseName,N'&',N'&amp;'),N'<',N'&lt;'),N'>',N'&gt;') + N'</td>'
      + N'<td style="' + @Td + Band + @Num + N'">' + FORMAT(DbSizeMB, 'N2') + N'</td>'
      + N'<td style="' + @Td + Band + N'">' + DatabaseState + N'</td>'
      + N'<td style="' + @Td + Band + N'">' + RecoveryModel + N'</td>'
      + N'<td style="' + @Td + Band + N'">' + ISNULL(REPLACE(REPLACE(REPLACE(FilegroupName,N'&',N'&amp;'),N'<',N'&lt;'),N'>',N'&gt;'), N'-') + N'</td>'
      + N'<td style="' + @Td + Band + N'">' + ISNULL(FilegroupType, N'-') + N'</td>'
      + N'<td style="' + @Td + Band + N'">' + REPLACE(REPLACE(REPLACE(LogicalFileName,N'&',N'&amp;'),N'<',N'&lt;'),N'>',N'&gt;') + N'</td>'
      + N'<td style="' + @Td + Band + N'">' + FileType + N'</td>'
      + N'<td style="' + @Td + Band + N'">' + REPLACE(REPLACE(REPLACE(PhysicalPath,N'&',N'&amp;'),N'<',N'&lt;'),N'>',N'&gt;') + N'</td>'
      + N'<td style="' + @Td + Band + N'">' + ISNULL(CAST(IsPrimaryFilestreamFile AS NVARCHAR(10)), N'-') + N'</td>'
      + N'<td style="' + @Td + SizeStyle + @Num + N'">' + FORMAT(SizeMB, 'N2') + N'</td>'
      + N'<td style="' + @Td + Band + @Num + N'">' + ISNULL(FORMAT(UsedMB, 'N2'), N'-') + N'</td>'
      + N'<td style="' + @Td + PctStyle + @Num + N'">' + ISNULL(FORMAT(UsedPct, 'N2') + N'%', N'-') + N'</td>'
      + N'<td style="' + @Td + Band + N'">' + Growth + N'</td>'
      + N'<td style="' + @Td + Band + N'">' + MaxSize + N'</td>'
      + N'<td style="' + @Td + Band + N'">' + FileState + N'</td>'
      + N'</tr>' AS NVARCHAR(MAX)), N'') WITHIN GROUP (ORDER BY rn)
FROM c;

SELECT @Summary = CAST(N'' AS NVARCHAR(MAX))
       + N'Databases: <span style="' + @Font + N'font-weight:700;">' + FORMAT(COUNT(DISTINCT DatabaseName), 'N0') + N'</span>'
       + N' &nbsp;|&nbsp; Files: <span style="' + @Font + N'font-weight:700;">' + FORMAT(COUNT(*), 'N0') + N'</span>'
       + N' &nbsp;|&nbsp; Total size: <span style="' + @Font + N'font-weight:700;">' + FORMAT(ISNULL(SUM(SizeMB), 0) / 1024.0, 'N2') + N' GB</span>'
FROM #FileInventory;

SELECT @SkipHtml = CAST(N'<p style="' + @Font + N'color:#A4262C;"><span style="' + @Font + N'font-weight:700;">Skipped databases (' + CAST(COUNT(*) AS NVARCHAR(10)) + N'):</span> ' AS NVARCHAR(MAX))
       + STRING_AGG(CAST(REPLACE(REPLACE(REPLACE(DatabaseName,N'&',N'&amp;'),N'<',N'&lt;'),N'>',N'&gt;')
                        + N' (' + REPLACE(REPLACE(Reason,N'<',N'&lt;'),N'>',N'&gt;') + N')' AS NVARCHAR(MAX)), N'; ')
                    WITHIN GROUP (ORDER BY DatabaseName)
       + N'</p>'
FROM #Skipped
HAVING COUNT(*) > 0;

SET @Body = CAST(N'' AS NVARCHAR(MAX))
    + N'<html><body style="' + @Font + N'">'
    + N'<p style="' + @Font + N'font-weight:700;color:#0078D4;">Database File Inventory - ' + @Server + N'</p>'
    + N'<p style="' + @Font + N'">Generated: ' + @RunTime + N' &nbsp;|&nbsp; ' + ISNULL(@Summary, N'') + N'</p>'
    + N'<p style="' + @Font + N'">'
    + N'<span style="' + @Font + @Red + N'padding:1px 6px;">&nbsp;</span> Used % &ge; ' + FORMAT(@CritPct, 'N0') + N'% &nbsp; '
    + N'<span style="' + @Font + @Yellow + N'padding:1px 6px;">&nbsp;</span> Used % ' + FORMAT(@WarnPct, 'N0') + N'-' + FORMAT(@CritPct, 'N0') + N'% &nbsp; '
    + N'<span style="' + @Font + @Red + @Bold + N'padding:1px 6px;">Size</span> &ge; ' + FORMAT(@LimitPct, 'N0') + N'% &nbsp; '
    + N'<span style="' + @Font + @Yellow + @Bold + N'padding:1px 6px;">Size</span> ' + FORMAT(@LimitWarnPct, 'N0') + N'-' + FORMAT(@LimitPct, 'N0') + N'% of file size limit (data 16 TB, log 2 TB)'
    + N'</p>'
    + N'<table style="border-collapse:collapse;' + @Font + N'">'
    + N'<tr>'
    + N'<th style="' + @Th + N'">Database</th>'
    + N'<th style="' + @Th + N'">DB Size (MB)</th>'
    + N'<th style="' + @Th + N'">State</th>'
    + N'<th style="' + @Th + N'">Recovery</th>'
    + N'<th style="' + @Th + N'">Filegroup</th>'
    + N'<th style="' + @Th + N'">FG Type</th>'
    + N'<th style="' + @Th + N'">Logical Name</th>'
    + N'<th style="' + @Th + N'">File Type</th>'
    + N'<th style="' + @Th + N'">Physical Path</th>'
    + N'<th style="' + @Th + N'">Primary FS</th>'
    + N'<th style="' + @Th + N'">Size (MB)</th>'
    + N'<th style="' + @Th + N'">Used (MB)</th>'
    + N'<th style="' + @Th + N'">Used %</th>'
    + N'<th style="' + @Th + N'">Growth</th>'
    + N'<th style="' + @Th + N'">Max Size</th>'
    + N'<th style="' + @Th + N'">File State</th>'
    + N'</tr>'
    + ISNULL(@Rows, N'<tr><td colspan="16" style="' + @Td + N'">No user database files found.</td></tr>')
    + N'</table>'
    + ISNULL(@SkipHtml, N'')
    + N'</body></html>';

SET @Subject = N'[' + @Server + N'] Database File Inventory - ' + CONVERT(NVARCHAR(10), SYSDATETIME(), 120);

EXEC msdb.dbo.sp_send_dbmail
     @profile_name = @MailProfile,
     @recipients   = @Recipients,
     @subject      = @Subject,
     @body         = @Body,
     @body_format  = 'HTML';

/* ================================================================
   5. EMAIL 2 - ALLOCATION BY FILE TYPE AND DRIVE LETTER
   ================================================================ */
SET @Rows = NULL;

;WITH a AS
(
    SELECT FileType,
           DiskDrive = SUBSTRING(PhysicalPath, 1, 1),
           SizeMB    = SUM(SizeMB)
    FROM #FileInventory
    GROUP BY FileType, SUBSTRING(PhysicalPath, 1, 1)
),
s AS
(
    SELECT a.*, rn = ROW_NUMBER() OVER (ORDER BY a.FileType, a.DiskDrive)
    FROM a
)
SELECT @Rows = STRING_AGG(CAST(
        N'<tr>'
      + N'<td style="' + @Td + CASE WHEN rn % 2 = 0 THEN @BandB ELSE @BandA END + N'">' + FileType + N'</td>'
      + N'<td style="' + @Td + CASE WHEN rn % 2 = 0 THEN @BandB ELSE @BandA END + N'">' + DiskDrive + N':</td>'
      + N'<td style="' + @Td + CASE WHEN rn % 2 = 0 THEN @BandB ELSE @BandA END + @Num + N'">' + FORMAT(SizeMB, 'N2') + N'</td>'
      + N'</tr>' AS NVARCHAR(MAX)), N'') WITHIN GROUP (ORDER BY rn)
FROM s;

SET @Body = CAST(N'' AS NVARCHAR(MAX))
    + N'<html><body style="' + @Font + N'">'
    + N'<p style="' + @Font + N'font-weight:700;color:#0078D4;">Database Allocation by File Type and Drive - ' + @Server + N'</p>'
    + N'<p style="' + @Font + N'">Generated: ' + @RunTime + N' &nbsp;|&nbsp; ' + ISNULL(@Summary, N'') + N'</p>'
    + N'<table style="border-collapse:collapse;' + @Font + N'">'
    + N'<tr>'
    + N'<th style="' + @Th + N'">File Type</th>'
    + N'<th style="' + @Th + N'">Disk Drive</th>'
    + N'<th style="' + @Th + N'">Size (MB)</th>'
    + N'</tr>'
    + ISNULL(@Rows, N'<tr><td colspan="3" style="' + @Td + N'">No user database files found.</td></tr>')
    + N'</table>'
    + N'</body></html>';

SET @Subject = N'[' + @Server + N'] Database Allocation by Drive - ' + CONVERT(NVARCHAR(10), SYSDATETIME(), 120);

EXEC msdb.dbo.sp_send_dbmail
     @profile_name = @MailProfile,
     @recipients   = @Recipients,
     @subject      = @Subject,
     @body         = @Body,
     @body_format  = 'HTML';

DROP TABLE #FileInventory;
DROP TABLE #Skipped;
