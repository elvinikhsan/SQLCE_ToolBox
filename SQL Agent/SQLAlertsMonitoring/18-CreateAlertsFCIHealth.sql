SET NOCOUNT ON;

DECLARE @curAlertName SYSNAME
      , @curErrorNumber INT
	  , @curErrorMessage NVARCHAR(MAX)
      , @operatorName SYSNAME = N'John.Doe';

DECLARE @ErrorMessages TABLE (ErrorNumber INT, AlertName NVARCHAR(50), ErrorMessage NVARCHAR(MAX));

INSERT INTO @ErrorMessages
VALUES (17883	,'Alert-FCINonYieldingWorker', 'A worker appears to be non-yielding on a scheduler. Can cause sp_server_diagnostics system component error and FCI failover.')
,(17884	,'Alert-FCIDeadlockedSchedulers', 'New queries assigned to a node have not been picked up by a worker thread (deadlocked schedulers).')
,(17887	,'Alert-FCINonYieldingIOCP', 'IO Completion Listener worker appears to be non-yielding on a node.')
,(17888	,'Alert-FCIAllSchedulersDeadlocked', 'All schedulers on a node appear deadlocked due to a large number of worker threads waiting.')
,(17890	,'Alert-FCIMemoryPagedOut', 'A significant part of SQL Server process memory has been paged out.')
,(701	,'Alert-FCIInsufficientMemory', 'There is insufficient system memory in resource pool to run this query.')
,(3449	,'Alert-FCIShutdownToRecoverDB', 'SQL Server must shut down in order to recover a database.')
,(17204	,'Alert-FCIFileOpenFailed1', 'FCB::Open failed - could not open a database file. Check cluster shared disk availability.')
,(17207	,'Alert-FCIFileOpenFailed2', 'FileMgr::StartLogFiles / FCB::Open - operating system error opening a database file. Check cluster shared disk availability.')
,(823	,'Alert-FCIStorageIOError', 'The operating system returned an error on an I/O against a database file (shared storage).')
,(824	,'Alert-FCIStorageLogicalIOError', 'SQL Server detected a logical consistency-based I/O error (torn page / bad checksum).')
,(825	,'Alert-FCIStorageReadRetry', 'A read of a database file succeeded only after retrying - early sign of storage failure.')
,(833	,'Alert-FCIStorageSlowIO', 'I/O requests taking longer than 15 seconds to complete on a database file.');

--SELECT * FROM @ErrorMessages;

DECLARE ForEachErrorMessage CURSOR LOCAL FAST_FORWARD FOR
SELECT * FROM @ErrorMessages;

OPEN ForEachErrorMessage;
FETCH NEXT FROM ForEachErrorMessage INTO @curErrorNumber, @curAlertName, @curErrorMessage;

WHILE @@FETCH_STATUS = 0
BEGIN
	IF NOT EXISTS(SELECT 1 FROM sys.messages m WHERE m.message_id = @curErrorNumber AND m.language_id = 1033)
	BEGIN
		RAISERROR('Skipped ''%s'': error number %d not found in sys.messages.', -1, -1, @curAlertName, @curErrorNumber) WITH NOWAIT;
	END
	ELSE IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysalerts s WHERE s.message_id = @curErrorNumber)
	BEGIN 
		EXECUTE msdb.dbo.sp_add_alert 
				@name = @curAlertName
			  , @message_id = @curErrorNumber
			  , @severity = 0
			  , @enabled = 1 
			  , @delay_between_responses = 300 
			  , @include_event_description_in = 1 
			  , @notification_message= @curErrorMessage
			  , @job_id = N'00000000-0000-0000-0000-000000000000';

		EXECUTE msdb.dbo.sp_add_notification @alert_name= @curAlertName, @operator_name= @operatorName, @notification_method = 1;

        RAISERROR('Alert ''%s'' for error number %d is created.', -1, -1, @curAlertName, @curErrorNumber) WITH NOWAIT;
    END

	FETCH NEXT FROM ForEachErrorMessage INTO @curErrorNumber, @curAlertName, @curErrorMessage;
END

CLOSE ForEachErrorMessage;
DEALLOCATE ForEachErrorMessage;
