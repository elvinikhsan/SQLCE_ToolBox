DECLARE @dbname SYSNAME; 
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX));
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DBName SYSNAME);
DECLARE @temp AS TABLE 
		(ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		,[DatabaseName] SYSNAME
		,ObjectName SYSNAME NULL
		,TypeDesc VARCHAR(25)
		,IndexName SYSNAME NULL
		,StatisticDate DATETIME NULL
		,AutoCreated BIT NULL
		,[NoRecompute] BIT NULL
		,UserCreated BIT NULL
		,[RowCount] INT NULL
		,[PageCount] INT NULL);

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
						SELECT ''' + REPLACE(@dbname, CHAR(39), CHAR(95)) + ''' AS [DatabaseName], SCHEMA_NAME(o.Schema_ID) + N''.'' + o.[NAME] AS [Object Name], o.[type_desc] AS [Object Type],
							  i.[name] AS [Index Name], STATS_DATE(i.[object_id], i.index_id) AS [Statistics Date], 
							  s.auto_created, s.no_recompute, s.user_created, st.row_count, st.used_page_count
						FROM sys.objects AS o WITH (NOLOCK)
						INNER JOIN sys.indexes AS i WITH (NOLOCK)
						ON o.[object_id] = i.[object_id]
						INNER JOIN sys.stats AS s WITH (NOLOCK)
						ON i.[object_id] = s.[object_id] 
						AND i.index_id = s.stats_id
						INNER JOIN sys.dm_db_partition_stats AS st WITH (NOLOCK)
						ON o.[object_id] = st.[object_id]
						AND i.[index_id] = st.[index_id]
						WHERE o.[type] IN (''U'', ''V'') AND DATEDIFF(DAY, STATS_DATE(i.[object_id], i.index_id), GETDATE()) >= 7
						AND st.row_count > 100000
						ORDER BY STATS_DATE(i.[object_id], i.index_id) DESC OPTION (RECOMPILE);'

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