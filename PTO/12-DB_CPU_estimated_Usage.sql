WITH DB_CPU_Usage
AS
(SELECT 
 dmpa.DatabaseID
 , DB_Name(dmpa.DatabaseID) AS [DB_Name]
 , SUM(dmqs.total_worker_time) AS CPU_Time_ms
 FROM sys.dm_exec_query_stats dmqs 
 CROSS APPLY 
 (SELECT 
 CONVERT(INT, value) AS [DatabaseID] 
 FROM sys.dm_exec_plan_attributes(dmqs.plan_handle)
 WHERE attribute = N'dbid') dmpa
 GROUP BY dmpa.DatabaseID)
 SELECT 
  @@SERVERNAME
 ,[DB_Name] 
 ,[CPU_Time_ms] 
 ,CAST([CPU_Time_ms] * 1.0 / SUM([CPU_Time_ms]) OVER() * 100.0 AS DECIMAL(5, 2)) AS [Percent]
 FROM DB_CPU_Usage
 ORDER BY [CPU_Time_ms] DESC;
GO