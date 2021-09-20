SELECT SCHEMA_NAME(o.Schema_ID) AS [Schema Name], OBJECT_NAME(p.object_id) AS [ObjectName], 
SUM(p.Rows) AS [RowCount], data_compression_desc AS [CompressionType]
FROM sys.partitions AS p WITH (NOLOCK)
INNER JOIN sys.objects AS o WITH (NOLOCK)
ON p.object_id = o.object_id
WHERE index_id < 2 --ignore the partitions from the non-clustered index if any
AND OBJECT_NAME(p.object_id) NOT LIKE N'sys%'
AND OBJECT_NAME(p.object_id) NOT LIKE N'spt_%'
AND OBJECT_NAME(p.object_id) NOT LIKE N'queue_%' 
AND OBJECT_NAME(p.object_id) NOT LIKE N'filestream_tombstone%' 
AND OBJECT_NAME(p.object_id) NOT LIKE N'fulltext%'
AND OBJECT_NAME(p.object_id) NOT LIKE N'ifts_comp_fragment%'
AND OBJECT_NAME(p.object_id) NOT LIKE N'filetable_updates%'
AND OBJECT_NAME(p.object_id) NOT LIKE N'xml_index_nodes%'
AND OBJECT_NAME(p.object_id) NOT LIKE N'sqlagent_job%'
AND OBJECT_NAME(p.object_id) NOT LIKE N'plan_persist%'
GROUP BY  SCHEMA_NAME(o.Schema_ID), p.object_id, data_compression_desc
ORDER BY SUM(p.Rows) DESC OPTION (RECOMPILE);
GO
--Table properties
SELECT OBJECT_NAME(t.[object_id]) AS [ObjectName], p.[rows] AS [Table Rows], p.index_id, 
       p.data_compression_desc AS [Index Data Compression],
       t.create_date, t.lock_on_bulk_load, t.is_replicated, t.has_replication_filter, 
       t.is_tracked_by_cdc, t.lock_escalation_desc, t.is_filetable, 
	   t.is_memory_optimized, t.durability_desc  -- new for SQL Server 2014
FROM sys.tables AS t WITH (NOLOCK)
INNER JOIN sys.partitions AS p WITH (NOLOCK)
ON t.[object_id] = p.[object_id]
WHERE OBJECT_NAME(t.[object_id]) NOT LIKE N'sys%'
ORDER BY OBJECT_NAME(t.[object_id]), p.index_id OPTION (RECOMPILE);