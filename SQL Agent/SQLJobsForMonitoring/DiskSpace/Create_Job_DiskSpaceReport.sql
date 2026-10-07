/*
    Create_Job_DiskSpaceReport.sql

    Purpose:
      Create SQL Agent job "DBA - Disk Space Report" that runs
      Send-DiskSpaceReport.ps1 daily in the morning (CmdExec step) and emails
      an HTML table of every local volume on the node with free-space
      highlighting (<= 5% red, <= 10% orange, <= 15% yellow).

    Before running:
      1. Copy Send-DiskSpaceReport.ps1 to the SAME local path on EVERY cluster node
         that can own this instance and set @ScriptPath to that path.
      2. Set @MailProfile and @Recipients.
      3. Check @SqlPort (default 1433).
         Set it to NULL if the instance name alone connects.
      4. Set @RunTime (HHMMSS, server local time) if 07:00 is not wanted.
      5. Optional: set @OperatorName for a failure email.

    Notes:
      - CmdExec is used (not the PowerShell subsystem) so the script's exit
        code (0 = success, 1 = failure) sets the job step result; same
        approach as the RBS Maintainer jobs.
      - The step runs as the SQL Agent service account, which needs read
        access to @ScriptPath.
      - Re-running this script drops and recreates the job (history lost).
*/

SET NOCOUNT ON;

DECLARE @JobName      SYSNAME       = N'DBA - Disk Space Report';
DECLARE @ScriptPath   NVARCHAR(400) = N'F:\temp\DiskSpace\Send-DiskSpaceReport.ps1';
DECLARE @MailProfile  SYSNAME       = N'DB_Mail';
DECLARE @Recipients   NVARCHAR(MAX) = N'john.doe@corp.contoso.com';   -- semicolon-separated
DECLARE @SqlPort      NVARCHAR(10)  = N'51933';           -- NULL = connect by name only
DECLARE @RunTime      INT           = 70000;              -- 07:00:00
DECLARE @OperatorName SYSNAME       = 'John.Doe';               -- e.g. N'DBA Team'

IF @MailProfile = N'<DatabaseMailProfile>' OR @Recipients = N'<Recipients>'
BEGIN
    ;THROW 50001, 'Set @MailProfile and @Recipients before running this script.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysmail_profile WHERE name = @MailProfile)
BEGIN
    ;THROW 50002, 'Database Mail profile in @MailProfile does not exist.', 1;
END;

IF @OperatorName IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = @OperatorName)
BEGIN
    ;THROW 50003, 'Operator in @OperatorName does not exist.', 1;
END;

DECLARE @SqlInstance NVARCHAR(300) = CAST(@@SERVERNAME AS NVARCHAR(256))
                                   + ISNULL(N',' + @SqlPort, N'');

DECLARE @Command NVARCHAR(MAX) =
      N'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass'
    + N' -File "'        + @ScriptPath  + N'"'
    + N' -SqlInstance "' + @SqlInstance + N'"'
    + N' -MailProfile "' + @MailProfile + N'"'
    + N' -Recipients "'  + @Recipients  + N'"';

DECLARE @Owner SYSNAME = SUSER_SNAME(0x01);   -- sa, even if renamed
DECLARE @jobId UNIQUEIDENTIFIER;

BEGIN TRANSACTION;
BEGIN TRY
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
        EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;

    IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE name = N'Database Maintenance' AND category_class = 1)
        EXEC msdb.dbo.sp_add_category @class = N'JOB', @type = N'LOCAL', @name = N'Database Maintenance';

    EXEC msdb.dbo.sp_add_job
         @job_name                   = @JobName,
         @enabled                    = 1,
         @description                = N'Daily HTML email: size / used / free space of every local volume (Send-DiskSpaceReport.ps1).',
         @category_name              = N'Database Maintenance',
         @owner_login_name           = @Owner,
         @notify_level_email         = CASE WHEN @OperatorName IS NULL THEN 0 ELSE 2 END,  -- 2 = on failure
         @notify_email_operator_name = @OperatorName,
         @job_id                     = @jobId OUTPUT;

    EXEC msdb.dbo.sp_add_jobstep
         @job_id            = @jobId,
         @step_name         = N'Send disk space email',
         @step_id           = 1,
         @subsystem         = N'CmdExec',
         @command           = @Command,
         @success_code      = 0,
         @on_success_action = 1,   -- quit with success
         @on_fail_action    = 2,   -- quit with failure
         @retry_attempts    = 0;

    EXEC msdb.dbo.sp_add_jobschedule
         @job_id            = @jobId,
         @name              = N'Daily - Morning',
         @enabled           = 1,
         @freq_type         = 4,   -- daily
         @freq_interval     = 1,
         @freq_subday_type  = 1,
         @active_start_time = @RunTime;

    EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)';

    COMMIT TRANSACTION;
    PRINT N'Job created: ' + @JobName;
    PRINT N'Step command: ' + @Command;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

/* Test run (optional):
   EXEC msdb.dbo.sp_start_job @job_name = N'DBA - Disk Space Report';
*/
