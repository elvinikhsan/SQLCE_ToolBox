DECLARE @dbname SYSNAME; 
DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, CommandText VARCHAR(MAX));
DECLARE @databases AS TABLE (ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, DBName SYSNAME);
DECLARE @temp AS TABLE 
		(ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		,[DatabaseName] SYSNAME
		,SchemaName SYSNAME
		,[TableName] VARCHAR(MAX)
		,IndexName VARCHAR(MAX)
		,IndexCols VARCHAR(MAX)
		,RedundantIndexName VARCHAR(MAX)
		,RedundantIndexCols VARCHAR(MAX)
		,object_id INT
		,index_id INT);

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
						;with IndexColumns AS(
						select distinct  schema_name (o.schema_id) as SchemaName,object_name(o.object_id) as TableName, i.Name as IndexName, o.object_id,i.index_id,i.type,
						(select case key_ordinal when 0 then NULL else ''[''+col_name(k.object_id,column_id) +'']'' end as [data()]
						from sys.index_columns  (NOLOCK) as k
						where k.object_id = i.object_id
						and k.index_id = i.index_id
						order by key_ordinal, column_id
						for xml path('''')) as cols,
						(select case key_ordinal when 0 then NULL else ''[''+col_name(k.object_id,column_id) +''] '' + CASE WHEN is_descending_key=1 THEN ''Desc'' ELSE ''Asc'' END end as [data()]
						from sys.index_columns  (NOLOCK) as k
						where k.object_id = i.object_id
						and k.index_id = i.index_id
						order by key_ordinal, column_id
						for xml path('''')) as colsWithSortOrder,
						case when i.index_id=1 then 
						(select ''[''+name+'']'' as [data()]
						from sys.columns  (NOLOCK) as c
						where c.object_id = i.object_id
						and c.column_id not in (select column_id from sys.index_columns  (NOLOCK) as kk    where kk.object_id = i.object_id and kk.index_id = i.index_id)
						order by column_id for xml path(''''))
						else
						(select ''[''+col_name(k.object_id,column_id) +'']'' as [data()]
						from sys.index_columns  (NOLOCK) as k
						where k.object_id = i.object_id
						and k.index_id = i.index_id and is_included_column=1 and k.column_id not in (Select column_id from sys.index_columns kk where k.object_id=kk.object_id and kk.index_id=1)
						order by key_ordinal, column_id for xml path('''')) end as inc
						from sys.indexes  (NOLOCK) as i
						inner join sys.objects o  (NOLOCK) on i.object_id =o.object_id 
						inner join sys.index_columns ic  (NOLOCK) on ic.object_id =i.object_id and ic.index_id =i.index_id
						inner join sys.columns c  (NOLOCK) on c.object_id = ic.object_id and c.column_id = ic.column_id
						where  o.type = ''U'' and i.index_id <>0 and i.type <>3 and i.type <>5 and i.type <>6 and i.type <>7
						group by o.schema_id,o.object_id,i.object_id,i.Name,i.index_id,i.type
						), ResultTable AS
						(SELECT    ic1.SchemaName,ic1.TableName,ic1.IndexName,ic1.object_id, ic2.IndexName as RedundantIndexName, CASE WHEN ic1.index_id=1 THEN ic1.colsWithSortOrder + '' (Clustered)'' WHEN ic1.inc = '''' THEN ic1.colsWithSortOrder  WHEN ic1.inc is NULL THEN ic1.colsWithSortOrder ELSE ic1.colsWithSortOrder + '' INCLUDE '' + ic1.inc END as IndexCols, 
						CASE WHEN ic2.index_id=1 THEN ic2.colsWithSortOrder + '' (Clustered)'' WHEN ic2.inc = '''' THEN ic2.colsWithSortOrder  WHEN ic2.inc is NULL THEN ic2.colsWithSortOrder ELSE ic2.colsWithSortOrder + '' INCLUDE '' + ic2.inc END as RedundantIndexCols, ic1.index_id
						,ic1.cols col1,ic2.cols col2
						from IndexColumns ic1 join IndexColumns ic2 on ic1.object_id = ic2.object_id
						and ic1.index_id <> ic2.index_id and not (ic1.colsWithSortOrder = ic2.colsWithSortOrder and ISNULL(ic1.inc,'''') = ISNULL(ic2.inc,''''))
						and not (ic1.index_id=1 AND ic1.cols = ic2.cols ) and ic1.cols like REPLACE (ic2.cols , ''['',''[[]'') + ''%''
						)
						SELECT  ''' + REPLACE(@dbname, CHAR(39), CHAR(95)) + ''' AS [DatabaseName],
								SchemaName,TableName, IndexName, IndexCols, RedundantIndexName, RedundantIndexCols, object_id, index_id
						FROM ResultTable
						ORDER BY 1,2,3,5;'

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
