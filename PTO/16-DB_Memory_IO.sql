WITH DB_IO_Usage
AS
(SELECT DB_NAME(database_id) AS [DB_Name],
CAST(SUM(num_of_bytes_read + num_of_bytes_written)/1048576 AS DECIMAL(12, 2)) AS io_in_mb
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS [DM_IO_STATS]
GROUP BY database_id)
SELECT @@SERVERNAME, [DB_Name], io_in_mb AS [Total_IO_MB],
       CAST(io_in_mb/ SUM(io_in_mb) OVER() * 100.0 AS DECIMAL(5,2)) AS [Percent]
FROM DB_IO_Usage
ORDER BY ROW_NUMBER() OVER(ORDER BY io_in_mb DESC) 
GO