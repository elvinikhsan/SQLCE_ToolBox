SELECT
    s.transaction_isolation_level,
    CASE s.transaction_isolation_level
        WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'ReadUncommitted'
        WHEN 2 THEN 'ReadCommitted'
        WHEN 3 THEN 'RepeatableRead'
        WHEN 4 THEN 'Serializable'
        WHEN 5 THEN 'Snapshot'
    END                                                         AS isolation_level_desc,
    COUNT(DISTINCT s.session_id)                                AS session_count,
    COUNT(c.connection_id)                                      AS connection_count,   -- > session_count when MARS is used
    COUNT(DISTINCT CASE WHEN s.open_transaction_count > 0
                        THEN s.session_id END)                  AS sessions_with_open_tran,
    COUNT(DISTINCT CASE WHEN s.status = 'sleeping'
                         AND s.open_transaction_count > 0
                        THEN s.session_id END)                  AS sleeping_with_open_tran
FROM sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_connections AS c
       ON c.session_id = s.session_id
WHERE s.is_user_process = 1
GROUP BY s.transaction_isolation_level
ORDER BY s.transaction_isolation_level;
GO