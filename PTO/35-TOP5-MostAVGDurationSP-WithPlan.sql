SELECT TOP 5 CASE WHEN a.database_id = 32767 then 'Resource' ELSE DB_NAME(database_id)END AS DBName
      ,OBJECT_SCHEMA_NAME(object_id,a.database_id) AS [SCHEMA_NAME]  
      ,OBJECT_NAME(object_id,a.database_id)AS [OBJECT_NAME]
      ,a.cached_time
      ,a.last_execution_time
      ,a.execution_count
	  ,qs.refcounts, qs.usecounts
      ,a.total_worker_time / a.execution_count AS AVG_CPU
      ,a.total_elapsed_time / a.execution_count AS AVG_ELAPSED
      ,a.total_logical_reads / a.execution_count AS AVG_LOGICAL_READS
      ,a.total_logical_writes / a.execution_count AS AVG_LOGICAL_WRITES
      ,a.total_physical_reads  / a.execution_count AS AVG_PHYSICAL_READS
	  ,qp.query_plan
FROM sys.dm_exec_procedure_stats a
JOIN [sys].[dm_exec_cached_plans] AS [qs] ON [a].[plan_handle] = [qs].[plan_handle]
CROSS APPLY [sys].[dm_exec_query_plan]([qs].[plan_handle]) AS [qp]
WHERE (a.database_id > 4 AND DB_NAME(database_id) <> 'Resource') 
AND qp.query_plan IS NOT NULL
ORDER BY AVG_ELAPSED DESC;
GO
SELECT TOP(5) DB_NAME(qs.database_id) AS DBName, p.name AS [SP Name], qs.min_elapsed_time, qs.total_elapsed_time/qs.execution_count AS [avg_elapsed_time], 
qs.max_elapsed_time, qs.last_elapsed_time, qs.total_elapsed_time, qs.execution_count, 
ISNULL(qs.execution_count/DATEDIFF(Minute, qs.cached_time, GETDATE()), 0) AS [Calls/Minute], 
qs.total_worker_time/qs.execution_count AS [AvgWorkerTime], 
qs.total_worker_time AS [TotalWorkerTime],
CASE WHEN CONVERT(nvarchar(max), qp.query_plan) LIKE N'%<MissingIndexes>%' THEN 1 ELSE 0 END AS [Has Missing Index],
FORMAT(qs.last_execution_time, 'yyyy-MM-dd HH:mm:ss', 'en-US') AS [Last Execution Time], 
FORMAT(qs.cached_time, 'yyyy-MM-dd HH:mm:ss', 'en-US') AS [Plan Cached Time]
FROM sys.procedures AS p WITH (NOLOCK)
INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK)
ON p.[object_id] = qs.[object_id]
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
--WHERE qs.database_id = DB_ID()
WHERE DATEDIFF(Minute, qs.cached_time, GETDATE()) > 0
ORDER BY avg_elapsed_time DESC OPTION (RECOMPILE);