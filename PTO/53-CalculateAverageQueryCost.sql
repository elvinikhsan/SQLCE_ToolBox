CREATE TABLE #SubtreeCost(StatementSubtreeCost DECIMAL(18,2));
;WITH XMLNAMESPACES
(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
INSERT INTO #SubtreeCost
SELECT
    CAST(n.value('(@StatementSubTreeCost)[1]', 'VARCHAR(128)') AS DECIMAL(18,2))
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS qn(n)
WHERE n.query('.').exist('//RelOp[@PhysicalOp="Parallelism"]') = 1;
SELECT AVG(StatementSubtreeCost) AS AverageSubtreeCost
FROM #SubtreeCost;
 
DROP TABLE #SubtreeCost;