USE [msdb]
GO
DECLARE @jobid UNIQUEIDENTIFIER ;
SELECT @jobid = job_id FROM msdb.dbo.sysjobs 
WHERE name = 'SendSQLDatabaseStatus';

EXEC msdb.dbo.sp_update_jobstep @job_id=@jobid, @step_id=1 , 
		@command=N'DECLARE @tableHTML  NVARCHAR(MAX) ;
DECLARE @count INT;
DECLARE @servername VARCHAR(4000); 

SELECT @servername=@@SERVERNAME;

SELECT @count=COUNT(*)
FROM sys.databases
WHERE state_desc <> ''ONLINE''

IF @count<>0
BEGIN
SET @tableHTML =
    N''<H1>SQL Database Status</H1>'' +
    N''<table border="1">'' +
    N''<tr><th>ServerName</th><th>DatabaseName</th><th>State_Desc</th></tr>'' +
    CAST ( ( SELECT td = @servername,		'''',
					td = name,		'''',
                    td = state_desc,		''''
              FROM sys.databases
              WHERE state_desc <> ''ONLINE''
              FOR XML PATH(''tr''), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N''</table>'' ;

EXEC msdb.dbo.sp_send_dbmail
				@profile_name = ''SQLMailAdmin'', --- this is my database mail profile name
				@recipients = ''john.doe@xxx.com; jane.doe@xxx.com'',
				@Subject = ''SQL Server Message - Database Status'',
				@body = @tableHTML,
				@body_format = ''HTML'';
END
'
GO
DECLARE @jobid UNIQUEIDENTIFIER ;
SELECT @jobid = job_id FROM msdb.dbo.sysjobs 
WHERE name = 'SendSQLDBChangeReport';

EXEC msdb.dbo.sp_update_jobstep @job_id=@jobid, @step_id=1 , 
		@command=N'SET NOCOUNT ON 

 
 CREATE TABLE #current_model_info 
 (dbname1 NVARCHAR(50), model NVARCHAR(50) ) 

 INSERT INTO #current_model_Info SELECT name,recovery_model_desc FROM sys.databases 

 DECLARE @tableHTML NVARCHAR(MAX) ; 
 DECLARE @Recmodel VARCHAR(100),@dbname VARCHAR(100), 
 @currentrecmodel VARCHAR(4000),@servername VARCHAR(4000) 

 SELECT @servername=@@SERVERNAME;
 
 DECLARE @count INT;
 SET @count=0; 
 
 SELECT @count = COUNT(*)
 FROM DBA_DB_Baseline_Recovery_model a 
 FULL OUTER JOIN #current_model_info b ON a.dbname=b.dbname1 
 WHERE a.recoverymodel <> b.model OR a.dbname IS NULL OR b.dbname1 IS NULL;
 
 IF @count <> 0
 BEGIN
 SET @tableHTML = 
 N''<html><body><h1><font size="5" color="blue">Database and Recovery Model Change Report</h1>'' + 
 N''<table border="1.5" width="40%">'' + 
 N''<tr><b><th>ServerName</th><th>OldDBName</th><th>CurrentDBName</th><th>'' +
 N''Expected recovery model</th><th>Changed recovery model</th></tr>'' + 
 CAST(( 
 SELECT 
 td = @servername,'''', 
 td = ISNULL(a.dbname,''NULL''), '''',
 td = ISNULL(UPPER(b.dbname1),''NULL''), '''', 
 td = ISNULL(a.recoverymodel,''NULL''), '''', 
 td = ISNULL(b.model ,''NULL''),''''
 FROM DBA_DB_Baseline_Recovery_model a 
 FULL OUTER JOIN #current_model_info b ON a.dbname=b.dbname1 
 WHERE a.recoverymodel <> b.model OR a.dbname IS NULL OR b.dbname1 IS NULL
 FOR XML PATH(''tr''), TYPE) AS NVARCHAR(MAX)) + 
 N''</table><BR><BR></body></html>'' 

 
 EXEC msdb.dbo.sp_send_dbmail @recipients = ''john.doe@xxx.com; jane.doe@xxx.com'',
 @subject = ''SQL Server Message - Database and Recovery Model'', 
 @body = @tableHTML, 
 @body_format = ''HTML'', 
 @profile_name = ''SQLMailAdmin'';
 
 END

 DROP TABLE #current_model_info 

GO'
GO

DECLARE @jobid UNIQUEIDENTIFIER ;
SELECT @jobid = job_id FROM msdb.dbo.sysjobs 
WHERE name = 'SendSQLJobStatus';

EXEC msdb.dbo.sp_update_jobstep @job_id=@jobid, @step_id=1 , 
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
DECLARE @servername VARCHAR(MAX);

SELECT @servername = @@SERVERNAME;

SET @tableHTML =
    N''<H1>SQL Agent Job Status</H1>'' +
    N''<table border="1">'' +
    N''<tr><th>ServerName</th><th>JobName</th><th>Enabled</th>'' +
    N''<th>CurrentStatus</th><th>LastRunTime</th><th>LastRunOutCome</th></tr>'' +
    CAST ( ( SELECT td = @servername,		'''',
                    td = JobName,		'''',
                    td = [Enabled],		'''',
                    td = CurrentStatus, '''',
                    td = LastRunTime,		'''',
                    td = LastRunOutCome,		''''
              FROM @tempjobs
              FOR XML PATH(''tr''), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N''</table>'' ;

EXEC msdb.dbo.sp_send_dbmail
				@profile_name = ''SQLMailAdmin'', --- this is my database mail profile name
				@recipients = ''john.doe@xxx.com; jane.doe@xxx.com'',
				@subject = ''SQL Server Message - Jobs Status'',
				@body = @tableHTML,
				@body_format = ''HTML'';
END
				
GO


'
GO

DECLARE @jobid UNIQUEIDENTIFIER ;
SELECT @jobid = job_id FROM msdb.dbo.sysjobs 
WHERE name = 'SendSQLLogSizeStatus';
EXEC msdb.dbo.sp_update_jobstep @job_id=@jobid, @step_id=1 , 
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
DECLARE @servername VARCHAR(4000);

SELECT @servername = @@SERVERNAME ;

SELECT @count=COUNT(*)
FROM @LogSpace
WHERE LogSize >= 1024;

IF @count<>0
BEGIN
SET @tableHTML =
    N''<H1>SQL Log Size Status</H1>'' +
    N''<table border="1">'' +
    N''<tr><th>ServerName</th><th>DatabaseName</th><th>LogSize</th>'' +
    N''<th>LogUsed</th><th>Status</th></tr>'' +
    CAST ( ( SELECT td = @servername,		'''',
					td = DatabaseName,		'''',
                    td = CAST(LogSize AS DECIMAL(20,2)),		'''',
                    td = CAST(LogUsed AS DECIMAL(20,2)),		'''',
                    td = Status,		''''
              FROM @LogSpace
              WHERE LogSize >= 1024
              FOR XML PATH(''tr''), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N''</table>'' ;

EXEC msdb.dbo.sp_send_dbmail
				@profile_name = ''SQLMailAdmin'', --- this is my database mail profile name
				@recipients = ''john.doe@xxx.com; jane.doe@xxx.com'',
				@Subject = ''SQL Server Message - Log Size Status'',
				@body = @tableHTML,
				@body_format = ''HTML'';
END
'
GO
DECLARE @jobid UNIQUEIDENTIFIER ;
SELECT @jobid = job_id FROM msdb.dbo.sysjobs 
WHERE name = 'SendSQLServiceStatus';

EXEC msdb.dbo.sp_update_jobstep @job_id=@jobid, @step_id=1 , 
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
    N''<tr><th>ServerName</th><th>ServiceName</th><th>ServiceStatus</th><th>StatusDateTime</th></tr>'' +
    CAST ( ( SELECT td = @ChkInstanceName,		'''',
					td = ServiceName,		'''',
                    td = ServiceStatus,		'''',
                    td = StatusDateTime,	''''
              FROM tempdb.dbo.ServicesServiceStatus      
              FOR XML PATH(''tr''), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N''</table>'' ;

EXEC msdb.dbo.sp_send_dbmail
				@profile_name = ''AOPSQLMailAdmin'', --- this is my database mail profile name
				@recipients = ''elvin.ikhsan@ag-it.com; dwi.suharto@ag-it.com; nugroho@ag-it.com'',
				@Subject = ''SQL Server Message - Service Status'',
				@body = @tableHTML,
				@body_format = ''HTML'';

DROP TABLE tempdb.dbo.ServicesServiceStatus    /*Perform cleanup*/
DROP TABLE tempdb.dbo.RegResult'
GO
DECLARE @jobid UNIQUEIDENTIFIER ;
SELECT @jobid = job_id FROM msdb.dbo.sysjobs 
WHERE name = 'SendSQLUpTimeStatus';

EXEC msdb.dbo.sp_update_jobstep @job_id=@jobid, @step_id=1 , 
		@command=N'SET NOCOUNT ON;

DECLARE @tableHTML  NVARCHAR(MAX) ;

SET @tableHTML =
    N''<H1>SQL UpTime Status</H1>'' +
    N''<table border="1">'' +
    N''<tr><th>ServerName</th><th>ServiceName</th>'' +
    N''<th>SQLServerUpTime</th></tr>'' +
    CAST ( ( SELECT td = @@SERVERNAME,		'''',
                    td = @@SERVICENAME,		'''',
                    td = RTRIM(CONVERT(CHAR(3),DATEDIFF(second,login_time,getdate())/86400)) + '':'' +
RIGHT(''00''+RTRIM(CONVERT(CHAR(2),DATEDIFF(second,login_time,getdate())%86400/3600)),2) + '':'' +
RIGHT(''00''+RTRIM(CONVERT(CHAR(2),DATEDIFF(second,login_time,getdate())%86400%3600/60)),2) + '':'' +
RIGHT(''00''+RTRIM(CONVERT(CHAR(2),DATEDIFF(second,login_time,getdate())%86400%3600%60)),2),		''''
              FROM sys.sysprocesses
			  WHERE spid = 1
              FOR XML PATH(''tr''), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N''</table>'' ;

EXEC msdb.dbo.sp_send_dbmail
				@profile_name = ''SQLMailAdmin'', --- this is my database mail profile name
				@recipients = ''john.doe@xxx.com; jane.doe@xxx.com'',
				@Subject = ''SQL Server Message - UpTime Status'',
				@body = @tableHTML,
				@body_format = ''HTML'';

'
GO

DECLARE @jobid UNIQUEIDENTIFIER ;
SELECT @jobid = job_id FROM msdb.dbo.sysjobs 
WHERE name = 'SendSQLDiskFreeSpaceStatus';

EXEC msdb.dbo.sp_update_jobstep @job_id=@jobid, @step_id=1 , 
		@command=N'SET NOCOUNT ON;

CREATE TABLE #temp_drive
(Drive CHAR(1), MBFree INT)
INSERT INTO #temp_drive
        ( Drive, MBFree )
EXEC xp_fixeddrives;
--SELECT Drive, MBFree, CAST(CAST(MBFree AS DECIMAL(18,2))/1024 AS DECIMAL(18,2)) AS GBFree
--FROM #temp_drive;

DECLARE @tableHTML  NVARCHAR(MAX) ;
DECLARE @machinename VARCHAR(255);

SELECT @machinename = CAST(SERVERPROPERTY(''MachineName'') AS VARCHAR(255));

SET @tableHTML =
    N''<H1>SQL Disk Free Space</H1>'' +
    N''<table border="1">'' +
    N''<tr><th>Server</th><th>Drive</th><th>MBFree</th><th>GBFree</th></tr>'' +
    CAST ( ( SELECT td = @machinename,			'''',
					td = Drive,		'''',
                    td = MBFree,		'''',
                    td = CAST(CAST(MBFree AS DECIMAL(18,2))/1024 AS DECIMAL(18,2)),		''''
              FROM #temp_drive
              FOR XML PATH(''tr''), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N''</table>'' ;

EXEC msdb.dbo.sp_send_dbmail
				@profile_name = ''SQLMailAdmin'', --- this is my database mail profile name
				@recipients = ''john.doe@xxx.com; jane.doe@xxx.com'',
				@Subject = ''SQL Server Message - Disk Free Space Status'',
				@body = @tableHTML,
				@body_format = ''HTML'';

DROP TABLE #temp_drive;
GO'
GO
