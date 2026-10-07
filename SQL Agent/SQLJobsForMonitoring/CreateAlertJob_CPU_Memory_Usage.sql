/*
	Test the alert/email path (after running this script):
	RAISERROR(60001, 10, 1, N'TEST', 95, 80, 5, 90);
	RAISERROR(60002, 10, 1, N'TEST', 95, 1024, 524288, 90);
*/
SET NOCOUNT ON;

DECLARE @operatorName     SYSNAME = N'John.Doe'
      , @CpuThresholdPct  INT     = 95
      , @MemThresholdPct  INT     = 95
      , @CpuSampleMinutes INT     = 5      -- ring buffer records one sample per minute
      , @jobName          SYSNAME = N'DBA - Resource Usage Check'
      , @cmd              NVARCHAR(MAX);

/* 1. Custom messages */
IF EXISTS (SELECT 1 FROM sys.messages WHERE message_id IN (60001, 60002) AND language_id = 1033
           AND [text] NOT LIKE N'High CPU on node%' AND [text] NOT LIKE N'High memory on node%')
BEGIN
	RAISERROR('Message 60001/60002 already exists with different text. Pick other message numbers.', 16, 1);
	RETURN;
END

IF NOT EXISTS (SELECT 1 FROM sys.messages WHERE message_id = 60001 AND language_id = 1033)
	EXEC sys.sp_addmessage @msgnum = 60001, @severity = 10, @lang = 'us_english', @with_log = 'TRUE'
	   , @msgtext = N'High CPU on node %s: average total CPU %d%% (SQL Server %d%%) over the last %d minutes exceeds threshold %d%%.';

IF NOT EXISTS (SELECT 1 FROM sys.messages WHERE message_id = 60002 AND language_id = 1033)
	EXEC sys.sp_addmessage @msgnum = 60002, @severity = 10, @lang = 'us_english', @with_log = 'TRUE'
	   , @msgtext = N'High memory on node %s: physical memory used %d%% (available %d MB of %d MB) exceeds threshold %d%%.';

/* 2. Alerts (900 s delay: a sustained condition emails at most every 15 minutes) */
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysalerts WHERE message_id = 60001)
BEGIN
	EXEC msdb.dbo.sp_add_alert @name = N'Alert-HighCPU', @message_id = 60001, @severity = 0, @enabled = 1
	   , @delay_between_responses = 900, @include_event_description_in = 1
	   , @job_id = N'00000000-0000-0000-0000-000000000000';
	EXEC msdb.dbo.sp_add_notification @alert_name = N'Alert-HighCPU', @operator_name = @operatorName, @notification_method = 1;
	RAISERROR('Alert ''Alert-HighCPU'' for message 60001 is created.', -1, -1) WITH NOWAIT;
END

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysalerts WHERE message_id = 60002)
BEGIN
	EXEC msdb.dbo.sp_add_alert @name = N'Alert-HighMemory', @message_id = 60002, @severity = 0, @enabled = 1
	   , @delay_between_responses = 900, @include_event_description_in = 1
	   , @job_id = N'00000000-0000-0000-0000-000000000000';
	EXEC msdb.dbo.sp_add_notification @alert_name = N'Alert-HighMemory', @operator_name = @operatorName, @notification_method = 1;
	RAISERROR('Alert ''Alert-HighMemory'' for message 60002 is created.', -1, -1) WITH NOWAIT;
END

/* 3. Check job */
SET @cmd = N'SET NOCOUNT ON;
DECLARE @CpuThresholdPct INT = {CPU}, @MemThresholdPct INT = {MEM}, @Samples INT = {MIN};
DECLARE @node NVARCHAR(128) = CAST(SERVERPROPERTY(''ComputerNamePhysicalNetBIOS'') AS NVARCHAR(128));
DECLARE @avgTotalCpu INT, @avgSqlCpu INT, @n INT;

SELECT @avgTotalCpu = AVG(100 - s.SystemIdle), @avgSqlCpu = AVG(s.SqlCpu), @n = COUNT(*)
FROM (SELECT TOP (@Samples)
             x.record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]'', ''int'') AS SystemIdle
           , x.record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]'', ''int'') AS SqlCpu
      FROM (SELECT [timestamp], CONVERT(XML, record) AS record
            FROM sys.dm_os_ring_buffers
            WHERE ring_buffer_type = N''RING_BUFFER_SCHEDULER_MONITOR''
              AND record LIKE N''%<SystemHealth>%'') AS x
      ORDER BY x.[timestamp] DESC) AS s;

IF @n = @Samples AND @avgTotalCpu >= @CpuThresholdPct
	RAISERROR(60001, 10, 1, @node, @avgTotalCpu, @avgSqlCpu, @Samples, @CpuThresholdPct);

DECLARE @memUsedPct INT, @availMB INT, @totalMB INT;
SELECT @totalMB    = total_physical_memory_kb / 1024
     , @availMB    = available_physical_memory_kb / 1024
     , @memUsedPct = 100 - (available_physical_memory_kb * 100 / total_physical_memory_kb)
FROM sys.dm_os_sys_memory;

IF @memUsedPct >= @MemThresholdPct
	RAISERROR(60002, 10, 1, @node, @memUsedPct, @availMB, @totalMB, @MemThresholdPct);';

SET @cmd = REPLACE(REPLACE(REPLACE(@cmd, N'{CPU}', CAST(@CpuThresholdPct AS NVARCHAR(10)))
                                       , N'{MEM}', CAST(@MemThresholdPct AS NVARCHAR(10)))
                                       , N'{MIN}', CAST(@CpuSampleMinutes AS NVARCHAR(10)));

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @jobName)
BEGIN
	DECLARE @owner SYSNAME = SUSER_SNAME(0x01);

	EXEC msdb.dbo.sp_add_job @job_name = @jobName, @enabled = 1, @owner_login_name = @owner
	   , @description = N'Raises messages 60001 (CPU) / 60002 (memory) when usage exceeds threshold. Alerts: Alert-HighCPU, Alert-HighMemory.';
	EXEC msdb.dbo.sp_add_jobstep @job_name = @jobName, @step_name = N'Check CPU and memory', @subsystem = N'TSQL'
	   , @database_name = N'master', @command = @cmd;
	EXEC msdb.dbo.sp_add_jobschedule @job_name = @jobName, @name = N'Every 5 minutes', @enabled = 1
	   , @freq_type = 4, @freq_interval = 1, @freq_subday_type = 4, @freq_subday_interval = 5;
	EXEC msdb.dbo.sp_add_jobserver @job_name = @jobName, @server_name = N'(local)';

	RAISERROR('Job ''%s'' is created.', -1, -1, @jobName) WITH NOWAIT;
END
