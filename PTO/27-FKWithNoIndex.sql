DECLARE @dbname SYSNAME; 
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX));
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DBName SYSNAME);
DECLARE @FKNoIndex AS TABLE 
		(ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		,[DatabaseName] SYSNAME
		,SchemaName VARCHAR(100)
		,[TableName] VARCHAR(250)
		,ConstraintName VARCHAR(250)
		,ReferencedSchemaName VARCHAR(100)
		,ReferencedTableName VARCHAR(250));

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
						;WITH FKTable 
						as(
							SELECT schema_name(o.schema_id) AS ''parent_schema_name'',object_name(FKC.parent_object_id) ''parent_table_name'',
							object_name(constraint_object_id) AS ''constraint_name'',schema_name(RO.Schema_id) AS ''referenced_schema'',object_name(referenced_object_id) AS ''referenced_table_name'',
							(SELECT ''[''+col_name(k.parent_object_id,parent_column_id) +'']'' AS [data()]
							  FROM sys.foreign_key_columns (NOLOCK) AS k
							  INNER JOIN sys.foreign_keys (NOLOCK)
							  ON k.constraint_object_id =object_id
							  AND k.constraint_object_id =FKC.constraint_object_id
							  ORDER BY constraint_column_id
							  FOR XML PATH('''') 
							) AS ''parent_colums'',
							(SELECT ''[''+col_name(k.referenced_object_id,referenced_column_id) +'']'' AS [data()]
							  FROM sys.foreign_key_columns (NOLOCK) AS k
							  INNER JOIN sys.foreign_keys (NOLOCK)
							  ON k.constraint_object_id =object_id
							  AND k.constraint_object_id =FKC.constraint_object_id
							  ORDER BY constraint_column_id
							  FOR XML PATH('''') 
							) AS ''referenced_columns''
						  FROM sys.foreign_key_columns FKC (NOLOCK)
						  INNER JOIN sys.objects o (NOLOCK) ON FKC.parent_object_id = o.object_id
						  INNER JOIN sys.objects RO (NOLOCK) ON FKC.referenced_object_id = RO.object_id
						  WHERE o.object_id in (SELECT object_id FROM sys.objects (NOLOCK) WHERE type =''U'') AND RO.object_id in (SELECT object_id FROM sys.objects (NOLOCK) WHERE type =''U'')
						  group by o.schema_id,RO.schema_id,FKC.parent_object_id,constraint_object_id,referenced_object_id
						),
						IndexColumnsTable AS
						(
						  SELECT distinct schema_name (o.schema_id) AS ''schema_name'',object_name(o.object_id) AS TableName,
						  (SELECT case key_ordinal when 0 then NULL else ''[''+col_name(k.object_id,column_id) +'']'' end AS [data()]
							FROM sys.index_columns (NOLOCK) AS k
							WHERE k.object_id = i.object_id
							AND k.index_id = i.index_id
							ORDER BY key_ordinal, column_id
							FOR XML PATH('''')
						  ) AS cols
						  FROM sys.indexes (NOLOCK) AS i
						  INNER JOIN sys.objects o (NOLOCK) ON i.object_id =o.object_id 
						  INNER JOIN sys.index_columns ic (NOLOCK) ON ic.object_id =i.object_id AND ic.index_id =i.index_id
						  INNER JOIN sys.columns c (NOLOCK) ON c.object_id = ic.object_id AND c.column_id = ic.column_id
						  WHERE i.object_id in (SELECT object_id FROM sys.objects (NOLOCK) WHERE type =''U'') AND i.index_id > 0
						  group by o.schema_id,o.object_id,i.object_id,i.Name,i.index_id,i.type
						)
						SELECT DISTINCT ''' + REPLACE(@dbname, CHAR(39), CHAR(95)) + ''' AS [DatabaseName],
						  fk.parent_schema_name AS SchemaName,
						  fk.parent_table_name AS TableName,
						  fk.constraint_name AS ConstraintName,
						  fk.referenced_schema AS ReferencedSchemaName,
						  fk.referenced_table_name AS ReferencedTableName
						FROM FKTable fk 
						WHERE (SELECT COUNT(*) AS NbIndexes  FROM IndexColumnsTable ict  WHERE fk.parent_schema_name = ict.schema_name AND fk.parent_table_name = ict.TableName  AND fk.parent_colums = ict.cols
						  ) = 0;'

		INSERT INTO @sqlcommand(CommandText) VALUES (@sqltext);
		SET @j=@j+1;
END  

--execute the commands
SET @j=1;
WHILE @j<= @count
BEGIN
	DECLARE @sqlcmd NVARCHAR(MAX)='';
	SELECT @sqlcmd = CommandText FROM @sqlcommand WHERE ID=@j;
	INSERT INTO @FKNoIndex
	EXEC (@sqlcmd);
	SET @j=@j+1;
END

SELECT * FROM @FKNoIndex ORDER BY ID;
