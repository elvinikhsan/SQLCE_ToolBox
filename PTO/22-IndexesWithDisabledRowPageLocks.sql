SELECT name indexname,allow_row_locks,allow_page_locks
FROM sys.indexes
WHERE allow_row_locks = 0 
AND allow_page_locks = 0
