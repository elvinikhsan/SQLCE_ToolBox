USE master;
GO

CREATE OR ALTER PROCEDURE dbo.sp_KillSleepingOpenTran
    @ThresholdMinutes INT = 60,
    @ReportOnly       BIT = 0
AS
/*------------------------------------------------------------------------------
  Usage
------------------------------------------------------------------------------*/
-- Dry run: list sessions idle >= 60 minutes with an open transaction
-- EXEC sp_KillSleepingOpenTran @ReportOnly = 1;

-- Kill with the default 60-minute threshold
-- EXEC sp_KillSleepingOpenTran;

-- Kill with a custom threshold (e.g. 15 minutes)
-- EXEC sp_KillSleepingOpenTran @ThresholdMinutes = 15;
-----------------------------------------------------------------------------------
BEGIN
    SET NOCOUNT ON;

    IF @ThresholdMinutes IS NULL OR @ThresholdMinutes < 1
    BEGIN
        RAISERROR('@ThresholdMinutes must be 1 or greater.', 16, 1);
        RETURN;
    END;

    DECLARE @Candidates TABLE
    (
        session_id             INT            NOT NULL PRIMARY KEY,
        login_name             NVARCHAR(128)  NULL,
        host_name              NVARCHAR(128)  NULL,
        program_name           NVARCHAR(128)  NULL,
        session_current_db     NVARCHAR(128)  NULL,
        tran_start_time        DATETIME       NULL,
        tran_duration_sec      INT            NULL,
        idle_duration_sec      INT            NULL,
        open_transaction_count INT            NULL,
        log_used_mb            DECIMAL(18,2)  NULL,
        last_sql_statement     NVARCHAR(MAX)  NULL,
        action_taken           VARCHAR(20)    NULL,
        error_message          NVARCHAR(4000) NULL
    );

    INSERT INTO @Candidates
        (session_id, login_name, host_name, program_name, session_current_db,
         tran_start_time, tran_duration_sec, idle_duration_sec,
         open_transaction_count, log_used_mb, last_sql_statement)
    SELECT
        s.session_id,
        s.login_name,
        s.host_name,
        s.program_name,
        DB_NAME(s.database_id),
        t.tran_start_time,
        DATEDIFF(SECOND, t.tran_start_time, GETDATE()),
        DATEDIFF(SECOND, s.last_request_end_time, GETDATE()),
        s.open_transaction_count,
        t.log_used_mb,
        ib.event_info
    FROM sys.dm_exec_sessions AS s
    CROSS APPLY (SELECT MIN(at.transaction_begin_time) AS tran_start_time,
                        CAST(SUM(ISNULL(dt.database_transaction_log_bytes_used, 0))
                             / 1048576.0 AS DECIMAL(18,2)) AS log_used_mb
                 FROM sys.dm_tran_session_transactions AS stt
                 JOIN sys.dm_tran_active_transactions AS at
                      ON at.transaction_id = stt.transaction_id
                 LEFT JOIN sys.dm_tran_database_transactions AS dt
                      ON dt.transaction_id = at.transaction_id
                 WHERE stt.session_id = s.session_id) AS t
    OUTER APPLY sys.dm_exec_input_buffer(s.session_id, NULL) AS ib
    WHERE s.is_user_process = 1
      AND s.session_id <> @@SPID
      AND s.status = 'sleeping'
      AND s.open_transaction_count > 0
      AND s.last_request_end_time <= DATEADD(MINUTE, -@ThresholdMinutes, GETDATE());

    DECLARE @spid INT,
            @sql  NVARCHAR(30);

    DECLARE candidate_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT session_id FROM @Candidates ORDER BY session_id;

    OPEN candidate_cur;
    FETCH NEXT FROM candidate_cur INTO @spid;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @ReportOnly = 1
        BEGIN
            UPDATE @Candidates SET action_taken = 'REPORT ONLY' WHERE session_id = @spid;
        END
        -- Re-check: the session may have resumed work since it was captured
        ELSE IF EXISTS (SELECT 1
                        FROM sys.dm_exec_sessions AS s
                        WHERE s.session_id = @spid
                          AND s.status = 'sleeping'
                          AND s.open_transaction_count > 0
                          AND s.last_request_end_time <= DATEADD(MINUTE, -@ThresholdMinutes, GETDATE()))
        BEGIN
            BEGIN TRY
                SET @sql = N'KILL ' + CAST(@spid AS NVARCHAR(10)) + N';';
                EXEC (@sql);

                UPDATE @Candidates SET action_taken = 'KILLED' WHERE session_id = @spid;
                RAISERROR('Killed session %d.', 0, 1, @spid) WITH NOWAIT;
            END TRY
            BEGIN CATCH
                UPDATE @Candidates
                SET action_taken  = 'FAILED',
                    error_message = ERROR_MESSAGE()
                WHERE session_id = @spid;
            END CATCH;
        END
        ELSE
        BEGIN
            UPDATE @Candidates SET action_taken = 'SKIPPED' WHERE session_id = @spid;  -- state changed
        END;

        FETCH NEXT FROM candidate_cur INTO @spid;
    END;

    CLOSE candidate_cur;
    DEALLOCATE candidate_cur;

    SELECT
        session_id,
        action_taken,
        login_name,
        host_name,
        program_name,
        session_current_db,
        tran_start_time,
        CONCAT(tran_duration_sec / 3600, ':',
               RIGHT(CONCAT('0', tran_duration_sec % 3600 / 60), 2), ':',
               RIGHT(CONCAT('0', tran_duration_sec % 60), 2))   AS tran_duration_hhmmss,
        CONCAT(idle_duration_sec / 3600, ':',
               RIGHT(CONCAT('0', idle_duration_sec % 3600 / 60), 2), ':',
               RIGHT(CONCAT('0', idle_duration_sec % 60), 2))   AS idle_duration_hhmmss,
        open_transaction_count,
        log_used_mb,
        last_sql_statement,
        error_message
    FROM @Candidates
    ORDER BY idle_duration_sec DESC;
END;
GO
