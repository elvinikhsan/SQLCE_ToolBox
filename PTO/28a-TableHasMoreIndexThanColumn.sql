DECLARE @dbname SYSNAME; 
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX));
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DBName SYSNAME);
DECLARE @TableMoreIndexThanColumn AS TABLE 
		(ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		,[DatabaseName] SYSNAME
		,SchemaName SYSNAME
		,[TableName] VARCHAR(MAX)
		,IndexCount INT
		,ColumnCount INT);

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
						schema_name(so.schema_id) AS ''SchemaName'',
						object_name(so.object_id) AS ''TableName'',
						CASE objectproperty(max(so.object_id), ''TableHasClustIndex'')
						WHEN 0 THEN count(si.index_id) - 1
						ELSE count(si.index_id)
						END AS ''IndexCount'',
						MAX(d.ColumnCount) AS ''ColumnCount''
						FROM sys.objects so (NOLOCK)
						JOIN sys.indexes si (NOLOCK) ON so.object_id = si.object_id AND so.type in (N''U'',N''V'')
						JOIN sysindexes dmv (NOLOCK) ON so.object_id = dmv.id AND si.index_id = dmv.indid
						FULL OUTER JOIN (SELECT object_id, count(1) AS ColumnCount FROM sys.columns (NOLOCK) GROUP BY object_id) d
						ON d.object_id = so.object_id
						WHERE so.is_ms_shipped = 0
						AND so.object_id not in (select major_id FROM sys.extended_properties (NOLOCK) where name = N''microsoft_database_tools_support'')
						AND indexproperty(so.object_id, si.name, ''IsStatistics'') = 0
						GROUP BY so.schema_id, so.object_id
						HAVING(CASE objectproperty(MAX(so.object_id), ''TableHasClustIndex'')
						WHEN 0 THEN COUNT(si.index_id) - 1
						ELSE COUNT(si.index_id)
						END > MAX(d.ColumnCount));'

		INSERT INTO @sqlcommand(CommandText) VALUES (@sqltext);
		SET @j=@j+1;
END  

--execute the commands
SET @j=1;
WHILE @j<= @count
BEGIN
	DECLARE @sqlcmd NVARCHAR(MAX)='';
	SELECT @sqlcmd = CommandText FROM @sqlcommand WHERE ID=@j;
	PRINT @sqlcmd
	--INSERT INTO @TableMoreIndexThanColumn
	--EXEC (@sqlcmd);
	SET @j=@j+1;
	BREAK;
END

SELECT * FROM @TableMoreIndexThanColumn ORDER BY ID;
