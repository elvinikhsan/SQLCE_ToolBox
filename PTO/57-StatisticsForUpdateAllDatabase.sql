DECLARE @dbname SYSNAME; 
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX));
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DBName SYSNAME);
DECLARE @tblStatsUpd AS TABLE 
		(ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		,[DatabaseName] SYSNAME
		,schemaName VARCHAR(100)
		,[tableName] VARCHAR(250)
		,last_updated DATETIME
		,[rows] bigint
		,modification_counter bigint
		,[stat_name] VARCHAR(255)
		,auto_created bit
		,user_created bit);

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
			SELECT DISTINCT ''' + REPLACE(@dbname, CHAR(39), CHAR(95)) + ''' AS [DatabaseName], t.name AS schemaName, OBJECT_NAME(mst.[object_id]) AS tableName, 
				sp.last_updated, sp.[rows], sp.modification_counter, ss.name AS [stat_name], ss.auto_created, ss.user_created
			FROM sys.objects AS o
			INNER JOIN sys.tables AS mst ON mst.[object_id] = o.[object_id]
			INNER JOIN sys.schemas AS t ON t.[schema_id] = mst.[schema_id]
			INNER JOIN sys.stats AS ss ON ss.[object_id] = mst.[object_id]
			CROSS APPLY sys.dm_db_stats_properties(ss.[object_id], ss.[stats_id]) AS sp
			WHERE sp.[rows] > 0
			AND	((sp.[rows] <= 500 AND sp.modification_counter >= 500)
				OR (sp.[rows] > 500 AND sp.modification_counter >= (500 + sp.[rows] * 0.20)))';

		INSERT INTO @sqlcommand(CommandText) VALUES (@sqltext);
		SET @j=@j+1;
END  

--execute the commands
SET @j=1;
WHILE @j<= @count
BEGIN
	DECLARE @sqlcmd NVARCHAR(MAX)='';
	SELECT @sqlcmd = CommandText FROM @sqlcommand WHERE ID=@j;
	INSERT INTO @tblStatsUpd
	EXEC (@sqlcmd);
	SET @j=@j+1;
END

SELECT * FROM @tblStatsUpd ORDER BY ID;

