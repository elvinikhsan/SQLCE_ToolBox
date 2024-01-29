DECLARE @dbname SYSNAME; 
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX));
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DBName SYSNAME);
DECLARE @temp AS TABLE 
		(ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		,[DatabaseName] SYSNAME
		,SchemaName SYSNAME
		,[TableName] VARCHAR(MAX)
		,IndexName VARCHAR(MAX)
		,TypeDesc SYSNAME
		,RowLength INT
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
						SELECT  ''' + REPLACE(@dbname, CHAR(39), CHAR(95)) + ''' AS [DatabaseName],
								schema_name (o.schema_id) AS SchemaName,o.name AS TableName, i.name AS IndexName, i.type_desc AS IndexType, sum(max_length) AS RowLength, count (ic.index_id) AS ColumnCount
						FROM sys.indexes i (NOLOCK) 
						INNER JOIN sys.objects o (NOLOCK)  ON i.object_id =o.object_id 
						INNER JOIN sys.index_columns ic  (NOLOCK) ON ic.object_id =i.object_id and ic.index_id =i.index_id
						INNER JOIN sys.columns c  (NOLOCK) ON c.object_id = ic.object_id and c.column_id = ic.column_id
						WHERE o.type =''U'' and i.index_id >0 and ic.is_included_column=0
						GROUP BY o.schema_id,o.object_id,o.name,i.object_id,i.name,i.index_id,i.type_desc
						HAVING (sum(max_length) > 900)
						ORDER BY 1,2,3;'

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
