DECLARE @dbname SYSNAME; 
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX));
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DBName SYSNAME);
DECLARE @temp AS TABLE 
		(ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		,[DatabaseName] SYSNAME
		,SchemaName SYSNAME NULL
		,ObjectName SYSNAME NULL
		,IndexName SYSNAME NULL
		,IndexID INT NULL
		,IndexType VARCHAR(100) NULL
		,AvgFragmentationPct FLOAT NULL
		,FragmentCount INT NULL
		,[PageCount] INT NULL
		,[FillFactor] INT NULL
		,HasFilter BIT NULL
		,FilterDefinition VARCHAR(MAX) NULL
		,AllowPageLocks BIT NULL);

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
						SELECT ''' + REPLACE(@dbname, CHAR(39), CHAR(95)) + ''' AS [DatabaseName], SCHEMA_NAME(o.[schema_id]) AS [Schema Name],
						OBJECT_NAME(ps.OBJECT_ID) AS [Object Name], i.[name] AS [Index Name], ps.index_id, 
						ps.index_type_desc, ps.avg_fragmentation_in_percent, 
						ps.fragment_count, ps.page_count, i.fill_factor, i.has_filter, 
						i.filter_definition, i.[allow_page_locks]
						FROM sys.dm_db_index_physical_stats(DB_ID(),NULL, NULL, NULL , N''LIMITED'') AS ps
						INNER JOIN sys.indexes AS i WITH (NOLOCK)
						ON ps.[object_id] = i.[object_id] 
						AND ps.index_id = i.index_id
						INNER JOIN sys.objects AS o WITH (NOLOCK)
						ON i.[object_id] = o.[object_id]
						WHERE ps.database_id = DB_ID()
						AND ps.page_count > 2500
						AND ps.avg_fragmentation_in_percent >= 70
						ORDER BY ps.avg_fragmentation_in_percent DESC OPTION (RECOMPILE);'

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