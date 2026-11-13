SELECT
    s.session_id,
    DB_NAME(dt.database_id)                                     AS database_name,
    DB_NAME(s.database_id)                                      AS session_current_db,
    at.transaction_id,
    at.name                                                     AS transaction_name,
    CASE at.transaction_type
        WHEN 1 THEN 'Read/Write'
        WHEN 2 THEN 'Read-only'
        WHEN 3 THEN 'System'
        WHEN 4 THEN 'Distributed'
    END                                                         AS transaction_type_desc,
    at.transaction_begin_time                                   AS tran_start_time,
    CONCAT(d.tran_sec / 3600, ':',
           RIGHT(CONCAT('0', d.tran_sec % 3600 / 60), 2), ':',
           RIGHT(CONCAT('0', d.tran_sec % 60), 2))              AS tran_duration_hhmmss,
    CONCAT(d.idle_sec / 3600, ':',
           RIGHT(CONCAT('0', d.idle_sec % 3600 / 60), 2), ':',
           RIGHT(CONCAT('0', d.idle_sec % 60), 2))              AS idle_duration_hhmmss,
    d.tran_sec                                                  AS tran_duration_sec,
    d.idle_sec                                                  AS idle_duration_sec,
    s.last_request_start_time,
    s.last_request_end_time,
    s.open_transaction_count,
    CASE s.transaction_isolation_level
        WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'ReadUncommitted'
        WHEN 2 THEN 'ReadCommitted'
        WHEN 3 THEN 'RepeatableRead'
        WHEN 4 THEN 'Serializable'
        WHEN 5 THEN 'Snapshot'
    END                                                         AS isolation_level_desc,
    dt.database_transaction_log_record_count                    AS log_record_count,
    CAST(dt.database_transaction_log_bytes_used     / 1048576.0 AS DECIMAL(18,2)) AS log_used_mb,
    CAST(dt.database_transaction_log_bytes_reserved / 1048576.0 AS DECIMAL(18,2)) AS log_reserved_mb,
    b.blocked_session_count,
    s.login_name,
    s.host_name,
    s.program_name,
    c.client_net_address,
    ib.event_info                                               AS last_sql_statement,  -- last input buffer
    st.text                                                     AS last_sql_batch       -- most recent batch text
FROM sys.dm_exec_sessions AS s
JOIN sys.dm_tran_session_transactions AS stt
     ON stt.session_id = s.session_id
JOIN sys.dm_tran_active_transactions AS at
     ON at.transaction_id = stt.transaction_id
LEFT JOIN sys.dm_tran_database_transactions AS dt
     ON dt.transaction_id = at.transaction_id
    AND dt.database_id <> 32767                      -- exclude resource database
LEFT JOIN sys.dm_exec_connections AS c
     ON c.session_id = s.session_id
    AND c.parent_connection_id IS NULL               -- exclude MARS child connections
CROSS APPLY (SELECT DATEDIFF(SECOND, at.transaction_begin_time, GETDATE()) AS tran_sec,
                    DATEDIFF(SECOND, s.last_request_end_time,  GETDATE()) AS idle_sec) AS d
OUTER APPLY (SELECT COUNT(*) AS blocked_session_count
             FROM sys.dm_exec_requests AS r
             WHERE r.blocking_session_id = s.session_id) AS b
OUTER APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) AS st
OUTER APPLY sys.dm_exec_input_buffer(s.session_id, NULL) AS ib
WHERE s.is_user_process = 1
  AND s.status = 'sleeping'
  AND s.open_transaction_count > 0
  AND s.session_id <> @@SPID
ORDER BY d.tran_sec DESC, s.session_id;
GO