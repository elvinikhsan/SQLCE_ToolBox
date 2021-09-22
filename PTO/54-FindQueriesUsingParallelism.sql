;WITH XMLNAMESPACES
(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT
    query_plan AS CompleteQueryPlan
    , n.value('(@StatementText)[1]', 'VARCHAR(4000)') AS StatementText
    , n.value('(@StatementOptmLevel)[1]', 'VARCHAR(25)') AS StatementOptimizationLevel
    , n.value('(@StatementSubTreeCost)[1]', 'VARCHAR(128)') AS StatementSubTreeCost
    , n.query('.') AS ParallelSubTreeXML
    , cp.usecounts
    , cp.size_in_bytes
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS qn(n)
WHERE n.query('.').exist('//RelOp[@PhysicalOp="Parallelism"]') = 1;