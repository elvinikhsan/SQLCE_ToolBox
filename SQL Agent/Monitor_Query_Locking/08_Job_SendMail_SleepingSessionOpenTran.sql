/*==============================================================================
  Open Transaction Email Report 

  Contents:
    Part A - dbo.sp_MailOpenTranReport (master): runs queries 1 and 2, builds
             an HTML email and sends it through Database Mail
    Part B - SQL Agent job that runs the procedure on a schedule

  Prerequisites:
    - Database Mail enabled and a working mail profile
    - SQL Server 2016 SP1 or later (CREATE OR ALTER, sys.dm_exec_input_buffer)
    - The job owner must be able to run msdb.dbo.sp_send_dbmail
      (sysadmin, or a member of DatabaseMailUserRole in msdb)

  Before running Part B, set @ProfileName and @Recipients.
==============================================================================*/


/*==============================================================================
  PART A - Report procedure
==============================================================================*/
USE master;
GO

CREATE OR ALTER PROCEDURE dbo.sp_MailOpenTranReport
    @ProfileName       SYSNAME,
    @Recipients        VARCHAR(MAX),
    @SendOnlyWhenFound BIT = 1      -- 1 = send only if a sleeping session with an open transaction exists
AS
BEGIN
    SET NOCOUNT ON;

    /*--------------------------------------------------------------------------
      Styles (Microsoft Fluent palette)
    --------------------------------------------------------------------------*/
    DECLARE
        @Band1   NVARCHAR(100) = N'background-color:#FFFFFF;',
        @Band2   NVARCHAR(100) = N'background-color:#F3F2F1;',
        @Red     NVARCHAR(100) = N'background-color:#E81123;color:#FFFFFF;font-weight:bold;',
        @Orange  NVARCHAR(100) = N'background-color:#FF8C00;color:#000000;font-weight:bold;',
        @Yellow  NVARCHAR(100) = N'background-color:#FFFF00;color:#000000;font-weight:bold;',
        @Right   NVARCHAR(50)  = N'text-align:right;',
        @ThStyle NVARCHAR(400) = N'background-color:#0078D4;color:#FFFFFF;font-family:''Segoe UI'',Arial,sans-serif;'
                               + N'font-size:9pt;font-weight:600;text-align:left;padding:4px 8px;border:1px solid #005A9E;';

    /*--------------------------------------------------------------------------
      Query 1 - sessions / connections by isolation level
    --------------------------------------------------------------------------*/
    SELECT
        ROW_NUMBER() OVER (ORDER BY s.transaction_isolation_level)  AS rn,
        CASE s.transaction_isolation_level
            WHEN 0 THEN 'Unspecified'
            WHEN 1 THEN 'ReadUncommitted'
            WHEN 2 THEN 'ReadCommitted'
            WHEN 3 THEN 'RepeatableRead'
            WHEN 4 THEN 'Serializable'
            WHEN 5 THEN 'Snapshot'
        END                                                         AS isolation_level_desc,
        COUNT(DISTINCT s.session_id)                                AS session_count,
        COUNT(c.connection_id)                                      AS connection_count,
        COUNT(DISTINCT CASE WHEN s.open_transaction_count > 0
                            THEN s.session_id END)                  AS sessions_with_open_tran,
        COUNT(DISTINCT CASE WHEN s.status = 'sleeping'
                             AND s.open_transaction_count > 0
                            THEN s.session_id END)                  AS sleeping_with_open_tran
    INTO #q1
    FROM sys.dm_exec_sessions AS s
    LEFT JOIN sys.dm_exec_connections AS c
           ON c.session_id = s.session_id
    WHERE s.is_user_process = 1
    GROUP BY s.transaction_isolation_level;

    /*--------------------------------------------------------------------------
      Query 2 - sleeping sessions with open transaction(s)
      Values are converted to text here so NULLs show as '-' and every
      HTML cell is always rendered.
    --------------------------------------------------------------------------*/
    SELECT
        ROW_NUMBER() OVER (ORDER BY d.tran_sec DESC, s.session_id)  AS rn,
        s.session_id,
        ISNULL(DB_NAME(dt.database_id), N'-')                       AS database_name,
        ISNULL(DB_NAME(s.database_id), N'-')                        AS session_current_db,
        ISNULL(CONVERT(VARCHAR(19), at.transaction_begin_time, 120), '-') AS tran_start_time,
        d.tran_sec,
        CONCAT(d.tran_sec / 3600, ':',
               RIGHT(CONCAT('0', d.tran_sec % 3600 / 60), 2), ':',
               RIGHT(CONCAT('0', d.tran_sec % 60), 2))              AS tran_duration,
        CONCAT(d.idle_sec / 3600, ':',
               RIGHT(CONCAT('0', d.idle_sec % 3600 / 60), 2), ':',
               RIGHT(CONCAT('0', d.idle_sec % 60), 2))              AS idle_duration,
        s.open_transaction_count,
        CASE s.transaction_isolation_level
            WHEN 0 THEN 'Unspecified'
            WHEN 1 THEN 'ReadUncommitted'
            WHEN 2 THEN 'ReadCommitted'
            WHEN 3 THEN 'RepeatableRead'
            WHEN 4 THEN 'Serializable'
            WHEN 5 THEN 'Snapshot'
        END                                                         AS isolation_level_desc,
        ISNULL(CONVERT(VARCHAR(30), CAST(dt.database_transaction_log_bytes_used / 1048576.0
                                         AS DECIMAL(18,2))), '-')   AS log_used_mb,
        b.blocked_session_count,
        s.login_name,
        ISNULL(s.host_name, N'-')                                   AS host_name,
        ISNULL(s.program_name, N'-')                                AS program_name,
        ISNULL(c.client_net_address, '-')                           AS client_net_address,
        ISNULL(LEFT(ib.event_info, 1000), N'-')                     AS last_sql_statement
    INTO #q2
    FROM sys.dm_exec_sessions AS s
    JOIN sys.dm_tran_session_transactions AS stt
         ON stt.session_id = s.session_id
    JOIN sys.dm_tran_active_transactions AS at
         ON at.transaction_id = stt.transaction_id
    LEFT JOIN sys.dm_tran_database_transactions AS dt
         ON dt.transaction_id = at.transaction_id
        AND dt.database_id <> 32767
    LEFT JOIN sys.dm_exec_connections AS c
         ON c.session_id = s.session_id
        AND c.parent_connection_id IS NULL
    CROSS APPLY (SELECT DATEDIFF(SECOND, at.transaction_begin_time, GETDATE()) AS tran_sec,
                        DATEDIFF(SECOND, s.last_request_end_time,  GETDATE()) AS idle_sec) AS d
    OUTER APPLY (SELECT COUNT(*) AS blocked_session_count
                 FROM sys.dm_exec_requests AS r
                 WHERE r.blocking_session_id = s.session_id) AS b
    OUTER APPLY sys.dm_exec_input_buffer(s.session_id, NULL) AS ib
    WHERE s.is_user_process = 1
      AND s.status = 'sleeping'
      AND s.open_transaction_count > 0
      AND s.session_id <> @@SPID;

    DECLARE @SleepingCount INT = (SELECT COUNT(DISTINCT session_id) FROM #q2);

    IF @SendOnlyWhenFound = 1 AND @SleepingCount = 0
        RETURN;

    /*--------------------------------------------------------------------------
      Table rows (FOR XML PATH escapes &, <, > in the data)
    --------------------------------------------------------------------------*/
    DECLARE @Rows1 NVARCHAR(MAX) = CAST((
        SELECT
            [td/@style] = CASE q.isolation_level_desc
                               WHEN 'Serializable'   THEN @Red
                               WHEN 'RepeatableRead' THEN @Yellow
                               ELSE b.bg END,
                                          td = q.isolation_level_desc,    '',
            [td/@style] = b.bg + @Right,  td = q.session_count,           '',
            [td/@style] = b.bg + @Right,  td = q.connection_count,        '',
            [td/@style] = b.bg + @Right,  td = q.sessions_with_open_tran, '',
            [td/@style] = CASE WHEN q.sleeping_with_open_tran > 0 THEN @Red ELSE b.bg END + @Right,
                                          td = q.sleeping_with_open_tran
        FROM #q1 AS q
        CROSS APPLY (SELECT CASE WHEN q.rn % 2 = 0 THEN @Band2 ELSE @Band1 END AS bg) AS b
        ORDER BY q.rn
        FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX));

    DECLARE @Rows2 NVARCHAR(MAX) = CAST((
        SELECT
            [td/@style] = b.bg + @Right,  td = q.session_id,              '',
            [td/@style] = b.bg,           td = q.database_name,           '',
            [td/@style] = b.bg,           td = q.session_current_db,      '',
            [td/@style] = b.bg,           td = q.tran_start_time,         '',
            [td/@style] = CASE WHEN q.tran_sec >= 1800 THEN @Red      -- >= 30 min
                               WHEN q.tran_sec >=  900 THEN @Orange   -- 15 to < 30 min
                               WHEN q.tran_sec >=  300 THEN @Yellow   --  5 to < 15 min
                               ELSE b.bg END + @Right,
                                          td = q.tran_duration,           '',
            [td/@style] = b.bg + @Right,  td = q.idle_duration,           '',
            [td/@style] = b.bg + @Right,  td = q.open_transaction_count,  '',
            [td/@style] = CASE q.isolation_level_desc
                               WHEN 'Serializable'   THEN @Red
                               WHEN 'RepeatableRead' THEN @Yellow
                               ELSE b.bg END,
                                          td = q.isolation_level_desc,    '',
            [td/@style] = b.bg + @Right,  td = q.log_used_mb,             '',
            [td/@style] = b.bg + @Right,  td = q.blocked_session_count,   '',
            [td/@style] = b.bg,           td = q.login_name,              '',
            [td/@style] = b.bg,           td = q.host_name,               '',
            [td/@style] = b.bg,           td = q.program_name,            '',
            [td/@style] = b.bg,           td = q.client_net_address,      '',
            [td/@style] = b.bg,           td = q.last_sql_statement
        FROM #q2 AS q
        CROSS APPLY (SELECT CASE WHEN q.rn % 2 = 0 THEN @Band2 ELSE @Band1 END AS bg) AS b
        ORDER BY q.rn
        FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX));

    IF @Rows2 IS NULL
        SET @Rows2 = N'<tr><td colspan="15" style="' + @Band1 + N'">No sleeping sessions with open transactions.</td></tr>';

    /*--------------------------------------------------------------------------
      Header rows
    --------------------------------------------------------------------------*/
    DECLARE @Hdr1 NVARCHAR(MAX) =
        N'<tr><th>Isolation Level</th><th>Sessions</th><th>Connections</th>'
      + N'<th>Sessions w/ Open Tran</th><th>Sleeping w/ Open Tran</th></tr>';

    DECLARE @Hdr2 NVARCHAR(MAX) =
        N'<tr><th>Session ID</th><th>Database</th><th>Session Current DB</th><th>Tran Start Time</th>'
      + N'<th>Tran Duration (h:mm:ss)</th><th>Idle Duration (h:mm:ss)</th><th>Open Tran Count</th>'
      + N'<th>Isolation Level</th><th>Log Used (MB)</th><th>Blocked Sessions</th><th>Login</th>'
      + N'<th>Host</th><th>Program</th><th>Client IP</th><th>Last SQL Statement</th></tr>';

    SET @Hdr1 = REPLACE(@Hdr1, N'<th>', N'<th style="' + @ThStyle + N'">');
    SET @Hdr2 = REPLACE(@Hdr2, N'<th>', N'<th style="' + @ThStyle + N'">');

    /*--------------------------------------------------------------------------
      Assemble HTML body
    --------------------------------------------------------------------------*/
    DECLARE @Body NVARCHAR(MAX) = CONCAT(
        N'<html><head><style>',
        N'body,table,td{font-family:''Segoe UI'',Arial,sans-serif;font-size:9pt;color:#323130;}',
        N'table{border-collapse:collapse;}',
        N'td{padding:3px 8px;border:1px solid #E1DFDD;vertical-align:top;}',
        N'h3{font-family:''Segoe UI'',Arial,sans-serif;font-size:11pt;color:#0078D4;margin:16px 0 6px 0;}',
        N'</style></head><body>',
        N'<p>Server: <b>', @@SERVERNAME, N'</b><br/>Generated: ', CONVERT(VARCHAR(19), GETDATE(), 120), N'</p>',

        N'<h3>1. Sessions by Isolation Level</h3>',
        N'<table>', @Hdr1, @Rows1, N'</table>',

        N'<h3>2. Sleeping Sessions with Open Transactions (', @SleepingCount, N')</h3>',
        N'<table>', @Hdr2, @Rows2, N'</table>',

        N'<p style="margin-top:8px;">Tran Duration: ',
        N'<span style="', @Yellow, N'padding:1px 6px;">5 to &lt; 15 min</span> ',
        N'<span style="', @Orange, N'padding:1px 6px;">15 to &lt; 30 min</span> ',
        N'<span style="', @Red,    N'padding:1px 6px;">&gt;= 30 min</span></p>',
        N'</body></html>');

    DECLARE @Subject NVARCHAR(255) = CONCAT(
        N'[', @@SERVERNAME, N'] Open Transaction Report - ',
        @SleepingCount, N' sleeping session(s) with open transaction');

    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = @ProfileName,
        @recipients   = @Recipients,
        @subject      = @Subject,
        @body         = @Body,
        @body_format  = 'HTML';
END;
GO


/*==============================================================================
  PART B - SQL Agent job
  Default schedule: every 15 minutes, all day. Adjust as needed.
==============================================================================*/
USE msdb;
GO

DECLARE
    @JobName     SYSNAME       = N'DBA - Open Transaction Report (Email)',
    @ProfileName SYSNAME       = N'<DatabaseMailProfile>',          -- set this
    @Recipients  NVARCHAR(500) = N'<dba-team@domain.go.id>',        -- set this; separate with ;
    @Owner       SYSNAME       = SUSER_SNAME(0x01),                 -- sa (works even if renamed)
    @Command     NVARCHAR(MAX);

SET @Command = CONCAT(
    N'EXEC dbo.sp_MailOpenTranReport',
    N' @ProfileName = N''', REPLACE(@ProfileName, N'''', N''''''), N'''',
    N', @Recipients = ''',  REPLACE(@Recipients,  N'''', N''''''), N'''',
    N', @SendOnlyWhenFound = 1;');

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
    EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;

EXEC msdb.dbo.sp_add_job
    @job_name         = @JobName,
    @enabled          = 1,
    @description      = N'Emails sessions by isolation level and sleeping sessions with open transactions (HTML).',
    @owner_login_name = @Owner;

EXEC msdb.dbo.sp_add_jobstep
    @job_name          = @JobName,
    @step_name         = N'Send open transaction report',
    @subsystem         = N'TSQL',
    @database_name     = N'master',
    @command           = @Command,
    @on_success_action = 1,     -- quit with success
    @on_fail_action    = 2;     -- quit with failure

EXEC msdb.dbo.sp_add_jobschedule
    @job_name             = @JobName,
    @name                 = N'Every 15 minutes',
    @enabled              = 1,
    @freq_type            = 4,  -- daily
    @freq_interval        = 1,
    @freq_subday_type     = 4,  -- minutes
    @freq_subday_interval = 15,
    @active_start_time    = 0;

EXEC msdb.dbo.sp_add_jobserver
    @job_name    = @JobName,
    @server_name = N'(local)';
GO
