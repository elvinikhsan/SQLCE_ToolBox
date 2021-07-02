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
ORDER BY AVG_CPU DESC