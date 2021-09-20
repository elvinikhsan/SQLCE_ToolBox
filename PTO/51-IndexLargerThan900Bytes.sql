SELECT schema_name (o.schema_id) AS 'SchemaName',o.name AS TableName, i.name AS IndexName, i.type_desc AS IndexType, sum(max_length) AS RowLength, count (ic.index_id) AS 'ColumnCount'
FROM sys.indexes i (NOLOCK) 
INNER JOIN sys.objects o (NOLOCK)  ON i.object_id =o.object_id 
INNER JOIN sys.index_columns ic  (NOLOCK) ON ic.object_id =i.object_id and ic.index_id =i.index_id
INNER JOIN sys.columns c  (NOLOCK) ON c.object_id = ic.object_id and c.column_id = ic.column_id
WHERE o.type ='U' and i.index_id >0 and ic.is_included_column=0
GROUP BY o.schema_id,o.object_id,o.name,i.object_id,i.name,i.index_id,i.type_desc
HAVING (sum(max_length) > 900)
ORDER BY 1,2,3
