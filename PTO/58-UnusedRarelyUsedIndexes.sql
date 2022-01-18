DECLARE @dbname SYSNAME; 
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX));
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DBName SYSNAME);
DECLARE @temp AS TABLE 
		(ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		,[DatabaseName] SYSNAME
		--,SchemaName VARCHAR(100)
		,[TableName] VARCHAR(250)
		,IndexName VARCHAR(250)
		,IndexType NVARCHAR(20)
		,IndexSize BIGINT
		,TotalWrites BIGINT
		,TotalReads BIGINT);

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
						SELECT DISTINCT ''' + REPLACE(@dbname, CHAR(39), CHAR(95)) + ''' AS [DatabaseName], 
						OBJECT_NAME(IX.OBJECT_ID) Table_Name
					   ,IX.name AS Index_Name
					   ,IX.type_desc Index_Type
					   ,SUM(PS.[used_page_count]) * 8 IndexSizeKB
					   ,IXUS.user_updates AS [TotalWrites]
					   ,IXUS.user_seeks + IXUS.user_scans + IXUS.user_lookups AS [TotalReads]
				FROM sys.indexes IX
				INNER JOIN sys.dm_db_index_usage_stats IXUS ON IXUS.index_id = IX.index_id AND IXUS.OBJECT_ID = IX.OBJECT_ID
				INNER JOIN sys.dm_db_partition_stats PS on PS.object_id=IX.object_id
				WHERE OBJECTPROPERTY(IX.OBJECT_ID,''IsUserTable'') = 1
				AND IXUS.database_id = DB_ID()
				AND IX.index_id > 1 AND IX.[type_desc] = N''NONCLUSTERED''
				AND IX.is_primary_key = 0 AND IX.is_unique_constraint = 0 AND IX.is_unique = 0
				AND ((IXUS.user_seeks + IXUS.user_scans + IXUS.user_lookups = 0)
				OR (IXUS.user_updates > (IXUS.user_seeks + IXUS.user_scans + IXUS.user_lookups)))
				GROUP BY OBJECT_NAME(IX.OBJECT_ID) ,IX.name ,IX.type_desc ,IXUS.user_seeks ,IXUS.user_scans ,IXUS.user_lookups,IXUS.user_updates;'

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