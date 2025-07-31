USE [msdb]
GO
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SendSQLLogSizeStatus', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'dbadmin', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Execute script]    Script Date: 06/17/2013 11:47:27 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute script', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;

DECLARE @LogSpace TABLE (
 [DatabaseName] VARCHAR (128),
 [LogSize] FLOAT,
 [LogUsed] FLOAT,
 [Status] INT);
 
 INSERT INTO @LogSpace
 EXEC (''DBCC SQLPERF (LOGSPACE)'');
 
DECLARE @tableHTML  NVARCHAR(MAX) ;
DECLARE @count INT;

SELECT @count=COUNT(*)
FROM @LogSpace
WHERE LogSize >= 1024
AND (LogUsed/LogSize)*100 >= 0.8;

IF @count<>0
BEGIN
SET @tableHTML =
    N''<H1>SQL Log Size Status</H1>'' +
    N''<table border="1">'' +
    N''<tr><th>DatabaseName</th><th>LogSize</th>'' +
    N''<th>LogUsed</th><th>Status</th></tr>'' +
    CAST ( ( SELECT td = DatabaseName,		'''',
                    td = CAST(LogSize AS DECIMAL(20,2)),		'''',
                    td = CAST(LogUsed AS DECIMAL(20,2)),		'''',
                    td = Status,		''''
              FROM @LogSpace
              WHERE LogSize >= 1024
			  AND (LogUsed/LogSize)*100 >= 0.8
              FOR XML PATH(''tr''), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N''</table>'' ;

EXEC msdb.dbo.sp_send_dbmail
				@profile_name = ''SQLAlertMail'', --- this is my database mail profile name
				@recipients = ''db.admin@bankmandiri.co.id'',
				@Subject = ''SQL Server Message - Log Size Status'',
				@body = @tableHTML,
				@body_format = ''HTML'';
END
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

