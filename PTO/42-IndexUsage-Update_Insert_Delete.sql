DECLARE @dbname SYSNAME; 
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX));
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DBName SYSNAME);
DECLARE @temp AS TABLE 
		(ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		,[DatabaseName] SYSNAME
		,TableName SYSNAME NULL
		,IndexName SYSNAME NULL
		,TypeDesc VARCHAR(25)
		,IndexSizeKB INT NULL
		,NumOfInserts INT NULL
		,NumOfUpdates INT NULL
		,NumOfDeletes INT NULL);

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
						SELECT ''' + REPLACE(@dbname, CHAR(39), CHAR(95)) + ''' AS [DatabaseName], OBJECT_NAME(IXOS.OBJECT_ID)  Table_Name 
							   ,IX.name  Index_Name
							   ,IX.type_desc Index_Type
							   ,SUM(PS.[used_page_count]) * 8 IndexSizeKB
							   ,IXOS.LEAF_INSERT_COUNT NumOfInserts
							   ,IXOS.LEAF_UPDATE_COUNT NumOfupdates
							   ,IXOS.LEAF_DELETE_COUNT NumOfDeletes
						FROM   SYS.DM_DB_INDEX_OPERATIONAL_STATS (NULL,NULL,NULL,NULL ) IXOS 
						INNER JOIN SYS.INDEXES AS IX ON IX.OBJECT_ID = IXOS.OBJECT_ID AND IX.INDEX_ID =    IXOS.INDEX_ID 
							INNER JOIN sys.dm_db_partition_stats PS on PS.object_id=IX.object_id
						WHERE  OBJECTPROPERTY(IX.[OBJECT_ID],''IsUserTable'') = 1
						GROUP BY OBJECT_NAME(IXOS.OBJECT_ID), IX.name, IX.type_desc,IXOS.LEAF_INSERT_COUNT, IXOS.LEAF_UPDATE_COUNT,IXOS.LEAF_DELETE_COUNT;'

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