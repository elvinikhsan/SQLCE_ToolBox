SELECT DB_NAME(database_id) AS [Database Name], [file_id], page_id, 
       event_type, error_count, last_update_date 
FROM msdb.dbo.suspect_pages WITH (NOLOCK)
ORDER BY database_id OPTION (RECOMPILE);