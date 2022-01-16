DECLARE @name SYSNAME; 
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX))
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DBName SYSNAME)
DECLARE @tblDRI AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, [database_name] SYSNAME, [schema_name] VARCHAR(100), [table_name] VARCHAR(200), [constraint_name] VARCHAR(200), [constraint_type] VARCHAR(10), alter_script VARCHAR(MAX))

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
		SELECT @name = DBName FROM @databases WHERE ID=@j;
		SET @sqltext = 'USE ' + QUOTENAME(@name) + '
		SELECT ''' + REPLACE(@name, CHAR(39), CHAR(95)) + ''' AS [database_name], t.name AS [schema_name], mst.name AS [table_name], FKC.name AS [constraint_name], ''ForeignKey'' As [constraint_type],
		''ALTER TABLE '' + QUOTENAME(t.name) + ''.'' + QUOTENAME(mst.name) + '' WITH CHECK CHECK CONSTRAINT '' + QUOTENAME(FKC.name) + '';'' AS alter_script
		FROM sys.foreign_keys FKC (NOLOCK)
		INNER JOIN sys.objects o (NOLOCK) ON FKC.parent_object_id = o.[object_id]
		INNER JOIN sys.tables mst (NOLOCK) ON mst.[object_id] = o.[object_id]
		INNER JOIN sys.schemas t (NOLOCK) ON t.[schema_id] = mst.[schema_id]
		WHERE o.type = ''U'' AND FKC.is_not_trusted = 1 AND FKC.is_not_for_replication = 0
		GROUP BY o.[schema_id], mst.[object_id], FKC.name, t.name, mst.name
		UNION ALL
		SELECT ''' + REPLACE(@name, CHAR(39), CHAR(95)) + ''' AS [database_name], t.name AS [schema_name], mst.name AS [table_name], CC.name AS [constraint_name], ''Check'' As [constraint_type],
		''ALTER TABLE '' + QUOTENAME(t.name) + ''.'' + QUOTENAME(mst.name) + '' WITH CHECK CHECK CONSTRAINT '' + QUOTENAME(CC.name) + '';'' AS alter_script
		FROM sys.check_constraints CC (NOLOCK)
		INNER JOIN sys.objects o (NOLOCK) ON CC.parent_object_id = o.[object_id]
		INNER JOIN sys.tables mst (NOLOCK) ON mst.[object_id] = o.[object_id]
		INNER JOIN sys.schemas t (NOLOCK) ON t.[schema_id] = mst.[schema_id]
		WHERE o.type = ''U'' AND CC.is_not_trusted = 1 AND CC.is_not_for_replication = 0 AND CC.is_disabled = 0
		GROUP BY t.[schema_id], mst.[object_id], CC.name, t.name, mst.name
		ORDER BY mst.name, [constraint_name];'
		INSERT INTO @sqlcommand(CommandText) VALUES (@sqltext);
		SET @j=@j+1;
END  

--execute the commands
SET @j=1;
WHILE @j<= @count
BEGIN
	DECLARE @sqlcmd NVARCHAR(MAX)='';
	SELECT @sqlcmd = CommandText FROM @sqlcommand WHERE ID=@j;
	INSERT INTO @tblDRI
	EXEC (@sqlcmd);
	SET @j=@j+1;
END

SELECT * FROM @tblDRI ORDER BY ID;

