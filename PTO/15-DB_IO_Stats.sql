USE master;
GO
WITH AggregateIOStatistics
AS
(SELECT DB_NAME(database_id) AS [DB Name],
CAST(SUM(num_of_bytes_read + num_of_bytes_written)/1048576 AS DECIMAL(12, 2)) AS io_in_mb
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS [DM_IO_STATS]
GROUP BY database_id)
SELECT ROW_NUMBER() OVER(ORDER BY io_in_mb DESC) AS [I/O Rank], [DB Name], io_in_mb AS [Total I/O (MB)],
       CAST(io_in_mb/ SUM(io_in_mb) OVER() * 100.0 AS DECIMAL(5,2)) AS [I/O Percent]
FROM AggregateIOStatistics
ORDER BY [I/O Rank] 
GO
SELECT  DB_NAME(divfs.database_id) as DatabaseName,
        mf.physical_name,
        divfs.num_of_reads,
        divfs.num_of_bytes_read,
        divfs.io_stall_read_ms,
        divfs.num_of_writes,
        divfs.num_of_bytes_written,
        divfs.io_stall_write_ms,
        divfs.io_stall,
        divfs.size_on_disk_bytes
FROM    sys.dm_io_virtual_file_stats(NULL, NULL) AS divfs
        JOIN sys.master_files AS mf ON mf.database_id = divfs.database_id
                                       AND mf.file_id = divfs.file_id;

GO