WITH DB_Memory_Usage AS (
SELECT CASE database_id WHEN 32767 THEN 'ResourceDB' ELSE DB_NAME(database_id) END as [DB_Name],
	   CAST(COUNT(*)* 8/1024 AS DECIMAL(12,2)) as [Cached_MB]
FROM sys.dm_os_buffer_descriptors
GROUP BY db_name(database_id) ,database_id)
SELECT @@SERVERNAME, [DB_Name], [Cached_MB], CAST([Cached_MB]/SUM([Cached_MB]) OVER() * 100.0 AS DECIMAL(5,2)) AS [Percent]
FROM DB_Memory_Usage
ORDER BY [Cached_MB] DESC;
GO