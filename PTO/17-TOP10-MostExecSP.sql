SELECT  TOP 10 DB_NAME(database_id) AS DatabaseName,
        OBJECT_NAME(object_id,database_id) AS ProcName,
		execution_count,
        total_elapsed_time / 1000000 TotElapsed,
		(total_elapsed_time/1000000)/execution_count AvgElapsed,
        last_elapsed_time / 1000000 LastElapsed,
        min_elapsed_time / 1000000 MinElapsed,
        max_elapsed_time / 1000000 MaxElapsed,
        max_logical_reads / 1000000 MaxRead,
        max_logical_writes / 1000000 MaxWrite
FROM    sys.dm_exec_procedure_stats
WHERE database_id > = 5 and database_id <= 32766
ORDER BY execution_count DESC
