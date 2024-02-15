SELECT [name] AS 'Database Name',
COUNT(li.database_id) AS 'VLF Count',
SUM(li.vlf_size_mb) AS 'VLF Size (MB)',
SUM(CAST(li.vlf_active AS INT)) AS 'Active VLF',
SUM(li.vlf_active*li.vlf_size_mb) AS 'Active VLF Size (MB)',
COUNT(li.database_id)-SUM(CAST(li.vlf_active AS INT)) AS 'Inactive VLF',
SUM(li.vlf_size_mb)-SUM(li.vlf_active*li.vlf_size_mb) AS 'Inactive VLF Size (MB)'
FROM sys.databases s
CROSS APPLY sys.dm_db_log_info(s.database_id) li
GROUP BY [name]
ORDER BY COUNT(li.database_id) DESC;