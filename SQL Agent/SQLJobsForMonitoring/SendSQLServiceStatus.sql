USE [msdb]
GO

/****** Object:  Job [SendSQLServiceStatus]    Script Date: 06/17/2013 11:48:45 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 06/17/2013 11:48:45 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SendSQLServiceStatus', 
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
/****** Object:  Step [Exec script]    Script Date: 06/17/2013 11:48:45 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Exec script', 
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

--Check SQL Server Services Status

CREATE TABLE tempdb.dbo.RegResult
   (
   ResultValue NVARCHAR(4)
   )

CREATE TABLE tempdb.dbo.ServicesServiceStatus  
   (
   RowID INT IDENTITY(1,1)
   ,ServerName NVARCHAR(128)
   ,ServiceName NVARCHAR(128)
   ,ServiceStatus VARCHAR(128)
   ,StatusDateTime DATETIME DEFAULT (GETDATE())
   ,PhysicalSrverName NVARCHAR(128)
   )

DECLARE
    @ChkInstanceName NVARCHAR(128)   /*Stores SQL Instance Name*/
   ,@ChkSrvName NVARCHAR(128)        /*Stores Server Name*/
   ,@TrueSrvName NVARCHAR(128)       /*Stores where code name needed */
   ,@SQLSrv NVARCHAR(128)            /*Stores server name*/
   ,@PhysicalSrvName NVARCHAR(128)   /*Stores physical name*/
   ,@DTS NVARCHAR(128)               /*Store SSIS Service Name */
   ,@FTS NVARCHAR(128)               /*Stores Full Text Search Service name*/
   ,@RS NVARCHAR(128)                /*Stores Reporting Service name*/
   ,@SQLAgent NVARCHAR(128)          /*Stores SQL Agent Service name*/
   ,@OLAP NVARCHAR(128)              /*Stores Analysis Service name*/
   ,@REGKEY NVARCHAR(128)            /*Stores Registry Key information*/


SET @PhysicalSrvName = CAST(SERVERPROPERTY(''MachineName'') AS VARCHAR(128))
SET @ChkSrvName = CAST(SERVERPROPERTY(''INSTANCENAME'') AS VARCHAR(128))
SET @ChkInstanceName = @@serverName

IF @ChkSrvName IS NULL        /*Detect default or named instance*/
BEGIN
   SET @TrueSrvName = ''MSSQLSERVER''
   SELECT @OLAP = ''MSSQLServerOLAPService''  /*Setting up proper service name*/
   SELECT @FTS = ''MSFTESQL''
   SELECT @RS = ''ReportServer''
   SELECT @SQLAgent = ''SQLSERVERAGENT''
   SELECT @SQLSrv = ''MSSQLSERVER''
END
ELSE
BEGIN
   SET @TrueSrvName =  CAST(SERVERPROPERTY(''INSTANCENAME'') AS VARCHAR(128))
   SET @SQLSrv = ''$''+@ChkSrvName
   SELECT @OLAP = ''MSOLAP'' + @SQLSrv /*Setting up proper service name*/
   SELECT @FTS = ''MSFTESQL'' + @SQLSrv
   SELECT @RS = ''ReportServer'' + @SQLSrv
   SELECT @SQLAgent = ''SQLAgent'' + @SQLSrv
   SELECT @SQLSrv = ''MSSQL'' + @SQLSrv
END


/* ---------------------------------- SQL Server Service Section ----------------------------------------------*/

SET @REGKEY = ''System\CurrentControlSet\Services\''+@SQLSrv

INSERT tempdb.dbo.RegResult ( ResultValue ) EXEC MASTER.sys.xp_regread @rootkey=''HKEY_LOCAL_MACHINE'', @key= @REGKEY

IF (SELECT ResultValue FROM tempdb.dbo.RegResult) = 1
BEGIN
   INSERT tempdb.dbo.ServicesServiceStatus (ServiceStatus)  /*Detecting staus of SQL Sever service*/
   EXEC xp_servicecontrol N''QUERYSTATE'',@SQLSrv
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''MS SQL Server Service'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END
ELSE
BEGIN
   INSERT INTO tempdb.dbo.ServicesServiceStatus (ServiceStatus) VALUES (''NOT INSTALLED'')
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''MS SQL Server Service'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END

/* ---------------------------------- SQL Server Agent Service Section -----------------------------------------*/

SET @REGKEY = ''System\CurrentControlSet\Services\''+@SQLAgent

INSERT tempdb.dbo.RegResult ( ResultValue ) EXEC MASTER.sys.xp_regread @rootkey=''HKEY_LOCAL_MACHINE'', @key= @REGKEY

IF (SELECT ResultValue FROM tempdb.dbo.RegResult) = 1
BEGIN
   INSERT tempdb.dbo.ServicesServiceStatus (ServiceStatus)  /*Detecting staus of SQL Agent service*/
   EXEC xp_servicecontrol N''QUERYSTATE'',@SQLAgent
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''SQL Server Agent Service'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus  SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END
ELSE
BEGIN
   INSERT INTO tempdb.dbo.ServicesServiceStatus (ServiceStatus) VALUES (''NOT INSTALLED'')
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''SQL Server Agent Service'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END


/* ---------------------------------- SQL Browser Service Section ----------------------------------------------*/

SET @REGKEY = ''System\CurrentControlSet\Services\SQLBrowser''

INSERT tempdb.dbo.RegResult ( ResultValue ) EXEC MASTER.sys.xp_regread @rootkey=''HKEY_LOCAL_MACHINE'', @key= @REGKEY

IF (SELECT ResultValue FROM tempdb.dbo.RegResult) = 1
BEGIN
   INSERT tempdb.dbo.ServicesServiceStatus (ServiceStatus)  /*Detecting staus of SQL Browser Service*/
   EXEC MASTER.dbo.xp_servicecontrol N''QUERYSTATE'',N''sqlbrowser''
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''SQL Browser Service - Instance Independent'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END
ELSE
BEGIN
   INSERT INTO tempdb.dbo.ServicesServiceStatus (ServiceStatus) VALUES (''NOT INSTALLED'')
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''SQL Browser Service - Instance Independent'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END

/* ---------------------------------- Integration Service Section ----------------------------------------------*/

IF CHARINDEX(''2008'',@@Version) > 0 SET @DTS=''MsDtsServer100''
IF CHARINDEX(''2005'',@@Version) > 0 SET @DTS= ''MsDtsServer''

SET @REGKEY = ''System\CurrentControlSet\Services\''+@DTS

INSERT tempdb.dbo.RegResult ( ResultValue ) EXEC MASTER.sys.xp_regread @rootkey=''HKEY_LOCAL_MACHINE'', @key= @REGKEY

IF (SELECT ResultValue FROM tempdb.dbo.RegResult) = 1
BEGIN
   INSERT tempdb.dbo.ServicesServiceStatus (ServiceStatus)  /*Detecting staus of Intergration Service*/
   EXEC MASTER.dbo.xp_servicecontrol N''QUERYSTATE'',@DTS
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''Integration Service - Instance Independent'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END
ELSE
BEGIN
   INSERT INTO tempdb.dbo.ServicesServiceStatus (ServiceStatus) VALUES (''NOT INSTALLED'')
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''Integration Service - Instance Independent'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END

/* ---------------------------------- Reporting Service Section ------------------------------------------------*/

SET @REGKEY = ''System\CurrentControlSet\Services\''+@RS

INSERT tempdb.dbo.RegResult ( ResultValue ) EXEC MASTER.sys.xp_regread @rootkey=''HKEY_LOCAL_MACHINE'', @key= @REGKEY

IF (SELECT ResultValue FROM tempdb.dbo.RegResult) = 1
BEGIN
   INSERT tempdb.dbo.ServicesServiceStatus (ServiceStatus)  /*Detecting staus of Reporting service*/
   EXEC MASTER.dbo.xp_servicecontrol N''QUERYSTATE'',@RS
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''Reporting Service'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END
ELSE
BEGIN
   INSERT INTO tempdb.dbo.ServicesServiceStatus (ServiceStatus) VALUES (''NOT INSTALLED'')
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''Reporting Service'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END

/* ---------------------------------- Analysis Service Section -------------------------------------------------*/
IF @ChkSrvName IS NULL        /*Detect default or named instance*/
   BEGIN
   SET @OLAP = ''MSSQLServerOLAPService''
END
ELSE
   BEGIN
   SET @OLAP = ''MSOLAP''+''$''+@ChkSrvName
   SET @REGKEY = ''System\CurrentControlSet\Services\''+@OLAP
END

INSERT tempdb.dbo.RegResult ( ResultValue ) EXEC MASTER.sys.xp_regread @rootkey=''HKEY_LOCAL_MACHINE'', @key= @REGKEY

IF (SELECT ResultValue FROM tempdb.dbo.RegResult) = 1
BEGIN
   INSERT tempdb.dbo.ServicesServiceStatus (ServiceStatus)  /*Detecting staus of Analysis service*/
   EXEC MASTER.dbo.xp_servicecontrol N''QUERYSTATE'',@OLAP
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''Analysis Services'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END
ELSE
BEGIN
   INSERT INTO tempdb.dbo.ServicesServiceStatus (ServiceStatus) VALUES (''NOT INSTALLED'')
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''Analysis Services'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END

/* ---------------------------------- Full Text Search Service Section -----------------------------------------*/

SET @REGKEY = ''System\CurrentControlSet\Services\''+@FTS

INSERT tempdb.dbo.RegResult ( ResultValue ) EXEC MASTER.sys.xp_regread @rootkey=''HKEY_LOCAL_MACHINE'', @key= @REGKEY

IF (SELECT ResultValue FROM tempdb.dbo.RegResult) = 1
BEGIN
   INSERT tempdb.dbo.ServicesServiceStatus (ServiceStatus)  /*Detecting staus of Full Text Search service*/
   EXEC MASTER.dbo.xp_servicecontrol N''QUERYSTATE'',@FTS
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''Full Text Search Service'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END
ELSE
BEGIN
   INSERT INTO tempdb.dbo.ServicesServiceStatus (ServiceStatus) VALUES (''NOT INSTALLED'')
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServiceName = ''Full Text Search Service'' WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET ServerName = @TrueSrvName WHERE RowID = @@identity
   UPDATE tempdb.dbo.ServicesServiceStatus SET PhysicalSrverName = @PhysicalSrvName WHERE RowID = @@identity
   TRUNCATE TABLE tempdb.dbo.RegResult
END

/* --Send DB Mail - Uncomment this section if you want to send email of the service(s) status*/

DECLARE @tableHTML  NVARCHAR(MAX) ;

SET @tableHTML =
    N''<H1>SQL Service Status</H1>'' +
    N''<table border="1">'' +
    N''<tr><th>ServiceName</th><th>ServiceStatus</th><th>StatusDateTime</th></tr>'' +
    CAST ( ( SELECT td = ServiceName,		'''',
                    td = ServiceStatus,		'''',
                    td = StatusDateTime,	''''
              FROM tempdb.dbo.ServicesServiceStatus      
              FOR XML PATH(''tr''), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N''</table>'' ;

EXEC msdb.dbo.sp_send_dbmail
				@profile_name = ''SQLMailAdmin'', --- this is my database mail profile name
				@recipients = ''john.doe@xxx.com; jane.doe@xxx.com'',
				@Subject = ''SQL Server Message - Service Status'',
				@body = @tableHTML,
				@body_format = ''HTML'';

DROP TABLE tempdb.dbo.ServicesServiceStatus    /*Perform cleanup*/
DROP TABLE tempdb.dbo.RegResult', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'SendSQLServerUpTimeStatus', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20130614, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959, 
		@schedule_uid=N'635c5ea4-fb33-4c35-a725-c97f13c39531'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO


