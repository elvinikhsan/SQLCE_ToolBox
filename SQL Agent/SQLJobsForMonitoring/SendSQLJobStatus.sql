USE [msdb]
GO

/****** Object:  Job [SendSQLJobStatus]    Script Date: 06/17/2013 11:44:55 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 06/17/2013 11:44:55 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SendSQLJobStatus', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Execute script check job status and send email]    Script Date: 06/17/2013 11:44:55 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute script check job status and send email', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET  NOCOUNT ON;
 
DECLARE @MaxLength   INT
SET @MaxLength   = 50
 
DECLARE @xp_results TABLE (
                       job_id uniqueidentifier NOT NULL,
                       last_run_date nvarchar (20) NOT NULL,
                       last_run_time nvarchar (20) NOT NULL,
                       next_run_date nvarchar (20) NOT NULL,
                       next_run_time nvarchar (20) NOT NULL,
                       next_run_schedule_id INT NOT NULL,
                       requested_to_run INT NOT NULL,
                       request_source INT NOT NULL,
                       request_source_id sysname
                             COLLATE database_default NULL,
                       running INT NOT NULL,
                       current_step INT NOT NULL,
                       current_retry_attempt INT NOT NULL,
                       job_state INT NOT NULL
                    )
 
DECLARE @job_owner   sysname
 
DECLARE @is_sysadmin   INT
SET @is_sysadmin   = isnull (is_srvrolemember (''sysadmin''), 0)
SET @job_owner   = suser_sname ()
 
INSERT INTO @xp_results
   EXECUTE sys.xp_sqlagent_enum_jobs @is_sysadmin, @job_owner
 
UPDATE @xp_results
   SET last_run_time    = right (''000000'' + last_run_time, 6),
       next_run_time    = right (''000000'' + next_run_time, 6);
       
DECLARE @tempjobs AS TABLE
(JobName VARCHAR(MAX)
,[Enabled] INT
, CurrentStatus VARCHAR(MAX)
, LastRunTime VARCHAR(MAX)
, LastRunOutCome VARCHAR(MAX));
       
WITH CTE AS( 
SELECT j.name AS JobName,
       j.enabled AS Enabled,
       CASE x.running
          WHEN 1
          THEN
             ''Running''
          ELSE
             CASE h.run_status
                WHEN 2 THEN ''Inactive''
                WHEN 4 THEN ''Inactive''
                ELSE ''Completed''
             END
       END
          AS CurrentStatus,
       coalesce (x.current_step, 0) AS CurrentStepNbr,
       CASE
          WHEN x.last_run_date > 0
          THEN
             convert (datetime,
                        substring (x.last_run_date, 1, 4)
                      + ''-''
                      + substring (x.last_run_date, 5, 2)
                      + ''-''
                      + substring (x.last_run_date, 7, 2)
                      + '' ''
                      + substring (x.last_run_time, 1, 2)
                      + '':''
                      + substring (x.last_run_time, 3, 2)
                      + '':''
                      + substring (x.last_run_time, 5, 2)
                      + ''.000'',
                      121
             )
          ELSE
             NULL
       END
          AS LastRunTime,
       CASE h.run_status
          WHEN 0 THEN ''Fail''
          WHEN 1 THEN ''Success''
          WHEN 2 THEN ''Retry''
          WHEN 3 THEN ''Cancel''
          WHEN 4 THEN ''In progress''
       END
          AS LastRunOutcome,
       CASE
          WHEN h.run_duration > 0
          THEN
               (h.run_duration / 1000000) * (3600 * 24)
             + (h.run_duration / 10000 % 100) * 3600
             + (h.run_duration / 100 % 100) * 60
             + (h.run_duration % 100)
          ELSE
             NULL
       END
          AS LastRunDuration
  FROM          @xp_results x
             LEFT JOIN
                msdb.dbo.sysjobs j
             ON x.job_id = j.job_id
          LEFT OUTER JOIN
             msdb.dbo.syscategories c
          ON j.category_id = c.category_id
       LEFT OUTER JOIN
          msdb.dbo.sysjobhistory h
       ON     x.job_id = h.job_id
          AND x.last_run_date = h.run_date
          AND x.last_run_time = h.run_time
          AND h.step_id = 0)
INSERT INTO @tempjobs 
SELECT JobName, ENABLED,CurrentStatus,LastRunTIme,LastRunOutCome FROM CTE 
WHERE LastRunOutCome=''Fail'' and
	LastRunTime>=(GETDATE()-2) ;

DECLARE @count INT;

SELECT @count=COUNT(*) FROM @tempjobs;

IF @count<>0
BEGIN
DECLARE @tableHTML  NVARCHAR(MAX) ;

SET @tableHTML =
    N''<H1>SQL Agent Job Status</H1>'' +
    N''<table border="1">'' +
    N''<tr><th>JobName</th><th>Enabled</th>'' +
    N''<th>CurrentStatus</th><th>LastRunTime</th><th>LastRunOutCome</th>'' +
    CAST ( ( SELECT td = JobName,		'''',
                    td = [Enabled],		'''',
                    td = CurrentStatus, '''',
                    td = LastRunTime,		'''',
                    td = LastRunOutCome,		''''
              FROM @tempjobs
              FOR XML PATH(''tr''), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N''</table>'' ;

EXEC msdb.dbo.sp_send_dbmail
				@profile_name = ''yourmailprofile'', --- this is the database mail profile name
				@recipients = ''john.doe@xxx.com; jane.doe@xxx.com'',
				@body = @tableHTML,
				@body_format = ''HTML'';
END
				
GO


', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'SQLJobStatusNotification', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=6, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20130612, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

