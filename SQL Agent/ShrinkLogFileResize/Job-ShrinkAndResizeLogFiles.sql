SET NOCOUNT ON;

DECLARE @dbname SYSNAME; 
DECLARE @filename SYSNAME;
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX));
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DatabaseID INT, DBName SYSNAME);
DECLARE @logfiles AS TABLE(ID INT, DBName SYSNAME, FileID INT, LogicalFileName SYSNAME);

DECLARE @temp AS TABLE 
		(ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		,[DatabaseName] SYSNAME
		,LogSizeMB Float NULL
		,LogSpaceUsedPct Float NULL
		,[Status] BIT NULL);

INSERT INTO @temp EXEC('DBCC SQLPERF(LOGSPACE)');

DECLARE @count INT = 0;
DECLARE @j INT =1;
DECLARE @counti INT;
DECLARE @i INT;

INSERT INTO @databases 
SELECT a.database_id, a.name 
FROM sys.databases a
INNER JOIN @temp b ON a.name = b.DatabaseName
WHERE a.name NOT IN ('master','model','msdb','tempdb') 
AND a.recovery_model_desc = 'SIMPLE'
AND a.state_desc = 'ONLINE'
AND b.LogSpaceUsedPct < 10
AND b.LogSizeMB > 1024
ORDER BY name;

INSERT INTO @logfiles
SELECT ROW_NUMBER() OVER (PARTITION BY a.DBName ORDER BY b.file_id) AS ID, a.DBName, b.file_id, b.name
FROM @databases a
INNER JOIN sys.master_files b ON a.DatabaseID = b.database_id
WHERE b.type_desc = 'LOG'
ORDER BY a.DBName, b.file_id ASC;

SELECT @count=COUNT(*) FROM @databases;

-- generate commands and store it in @sqlcommand
WHILE @j <= @count
BEGIN  
		DECLARE @sqltext VARCHAR(MAX)='';
		SELECT @dbname = DBName FROM @databases WHERE ID=@j;
		
		SET @counti = 0;
		SET @i = 1;

		SELECT @counti = COUNT(*) FROM @logfiles WHERE DBName = @dbname;

		WHILE @i <= @counti
		BEGIN
			SELECT @filename = LogicalFileName FROM @logfiles WHERE DBName = @dbname AND ID = @i;

			SET @sqltext = 'USE ' + QUOTENAME(@dbname) + ';
							DBCC SHRINKFILE(' + @filename + ', 1);';

			INSERT INTO @sqlcommand(CommandText) VALUES (@sqltext);

			SET @sqltext = 'ALTER DATABASE ' + QUOTENAME(@dbname) + ' MODIFY FILE (NAME = ' + @filename + ', SIZE = 1024MB, FILEGROWTH = 100MB);';

			INSERT INTO @sqlcommand(CommandText) VALUES (@sqltext);

			SET @i = @i + 1;
		END

		SET @j  =@j + 1;
END  

--execute the commands
SET @j = 1;
SET @count = (SELECT COUNT(*) FROM @sqlcommand);

WHILE @j <= @count
BEGIN
	DECLARE @sqlcmd NVARCHAR(MAX)='';
	SELECT @sqlcmd = CommandText FROM @sqlcommand WHERE ID=@j;
	RAISERROR(@sqlcmd,0,1) WITH NOWAIT;
	EXEC (@sqlcmd);
	SET @j=@j+1;
END

