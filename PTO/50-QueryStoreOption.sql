DECLARE @dbname SYSNAME; 
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX));
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DBName SYSNAME);
DECLARE @temp AS TABLE 
		(ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		,[DatabaseName] SYSNAME
		,ActualStateDesc VARCHAR(20) NULL
		,DesiredStateDesc VARCHAR(20) NULL
		,IntervalLengthMins INT NULL
		,CurrentStorageSizeMB INT NULL
		,MaxStorageSizeMB INT NULL
		,QueryCaptureMode VARCHAR(20) NULL
		,SizeBasedCleaneUpMode VARCHAR(20) NULL);

DECLARE @count INT = 0;
DECLARE @j INT =1;

INSERT INTO @databases SELECT name 
FROM master.dbo.sysdatabases 
WHERE name NOT IN ('master','model','msdb','tempdb')  
ORDER BY name;

SELECT @count=COUNT(*) FROM @databases;

-- generate commands and store it in @sqlcommand
WHILE @j <= @count
BEGIN  
		DECLARE @sqltext VARCHAR(MAX)='';
		SELECT @dbname = DBName FROM @databases WHERE ID=@j;
		SET @sqltext = 'USE ' + QUOTENAME(@dbname) + ';
						SELECT ''' + REPLACE(@dbname, CHAR(39), CHAR(95)) + ''' AS [DatabaseName], 
							   actual_state_desc, desired_state_desc, [interval_length_minutes],
							   current_storage_size_mb, [max_storage_size_mb], 
							   query_capture_mode_desc, size_based_cleanup_mode_desc
						FROM sys.database_query_store_options WITH (NOLOCK) OPTION (RECOMPILE);'

		INSERT INTO @sqlcommand(CommandText) VALUES (@sqltext);
		SET @j=@j+1;
END  

--execute the commands
SET @j=1;
WHILE @j<= @count
BEGIN
	DECLARE @sqlcmd NVARCHAR(MAX)='';
	SELECT @sqlcmd = CommandText FROM @sqlcommand WHERE ID=@j;
	INSERT INTO @temp
	EXEC (@sqlcmd);
	SET @j=@j+1;
END

SELECT * FROM @temp ORDER BY ID;

