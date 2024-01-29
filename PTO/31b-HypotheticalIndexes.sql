DECLARE @dbname SYSNAME; 
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX));
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DBName SYSNAME);
DECLARE @temp AS TABLE 
		(ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		,[DatabaseName] SYSNAME
		,SchemaName SYSNAME NULL
		,TableName VARCHAR(MAX) NULL
		,IndexName VARCHAR(MAX) NULL
		,IndexId INT NULL
		,TypeDesc VARCHAR(25)
		,Hypothetical BIT NULL);

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
						SELECT DISTINCT ''' + REPLACE(@dbname, CHAR(39), CHAR(95)) + ''' AS [DatabaseName], SCHEMA_NAME(a.schema_id) AS ''SchemaName'',OBJECT_NAME(a.object_id) AS ''TableName'', b.name AS ''IndexName'',b.index_id AS ''index_id'',b.type_desc AS ''IndexType'', indexproperty(a.object_id, b.name, ''IsHypothetical'') AS Hypothetical
						FROM sys.objects a (NOLOCK)
						JOIN sys.indexes b (NOLOCK) ON b.object_id = a.object_id
						AND a.is_ms_shipped = 0
						AND a.object_id NOT IN (SELECT major_id FROM sys.extended_properties (NOLOCK) WHERE name = N''microsoft_database_tools_support'')
						WHERE indexproperty(a.object_id, b.name, ''IsHypothetical'') = 1
						ORDER BY 1,2,3;';

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