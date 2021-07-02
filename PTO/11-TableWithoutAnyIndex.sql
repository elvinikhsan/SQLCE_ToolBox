SELECT DISTINCT 
schema_name(so.schema_id) AS 'SchemaName', object_name(so.object_id) AS 'TableName',
so.object_id AS 'object_id', max(dmv.rows) AS 'ApproximateRows',MAX(d.ColumnCount) AS 'ColumnCount'
FROM sys.objects so (NOLOCK) 
JOIN sys.indexes si (NOLOCK) ON so.object_id = si.object_id AND so.type in (N'U',N'V') 
JOIN sysindexes dmv (NOLOCK) ON so.object_id = dmv.id AND si.index_id = dmv.indid
FULL OUTER JOIN (SELECT object_id, count(1) AS ColumnCount FROM sys.columns (NOLOCK) GROUP BY object_id) d ON d.object_id = so.object_id
WHERE so.is_ms_shipped = 0 AND so.object_id NOT IN (SELECT major_id FROM sys.extended_properties (NOLOCK) WHERE name = N'microsoft_database_tools_support') 
AND indexproperty(so.object_id, si.name, 'IsStatistics') = 0
GROUP BY so.schema_id, so.object_id
HAVING( CASE objectproperty(MAX(so.object_id), 'TableHasClustIndex') WHEN 0 THEN COUNT(si.index_id) - 1 ELSE COUNT(si.index_id) END  = 0)
ORDER BY SchemaName, TableName;
