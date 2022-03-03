DECLARE @dbname SYSNAME; 
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX));
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DBName SYSNAME);
DECLARE @temp AS TABLE 
		(ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		,[DatabaseName] SYSNAME
		,SchemaName SYSNAME NULL
		,ObjectName SYSNAME NULL
		,[RowCount] BIGINT NULL
		,TypeDesc VARCHAR(25)
		,IndexID INT NULL
		,DataCompression VARCHAR(25) NULL
		,CreatedDate DATETIME NULL
		,IsReplicated BIT NULL
		,IsTrackedByCDC BIT NULL
		,LockEscalationDesc VARCHAR(25) NULL);

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
						SELECT ''' + REPLACE(@dbname, CHAR(39), CHAR(95)) + ''' AS [DatabaseName], SCHEMA_NAME(t.schema_id) AS SchemaName, t.name AS ObjectName, p.[rows] AS [RowCount], 
							   t.type_desc, p.index_id AS IndexID, p.data_compression_desc AS [DataCompression], t.create_date AS CreatedDate, t.is_replicated AS IsReplicated, 
							   t.is_tracked_by_cdc AS IsTrackedByCDC, t.lock_escalation_desc AS LockEscalationMode
						FROM sys.tables AS t WITH (NOLOCK)
						INNER JOIN sys.partitions AS p WITH (NOLOCK)
						ON t.[object_id] = p.[object_id]
						WHERE OBJECT_NAME(t.[object_id]) NOT LIKE N''sys%'' AND rows >= 100000
						ORDER BY p.[rows] DESC, t.name, p.index_id OPTION (RECOMPILE);'

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

