SET NOCOUNT ON;

DECLARE @curAlertName SYSNAME
      , @curErrorNumber INT
	  , @curErrorMessage NVARCHAR(MAX)
      , @operatorName SYSNAME = N'DB.Admin';

DECLARE @ErrorMessages TABLE (ErrorNumber INT, AlertName NVARCHAR(50), ErrorMessage NVARCHAR(MAX));

INSERT INTO @ErrorMessages
VALUES (1480	,'Alert-AGRoleChange', 'The AG is changing roles because availability group failed over.')
,(19407	,'Alert-AGLeaseExpired', 'The lease between availability group and the Windows Server Failover Cluster has expired.')
,(19419	,'Alert-AGWSFCLeaseSignalTimeout', 'Windows Server Failover Cluster did not receive a process event signal from SQL Server hosting availability group.')
,(19421	,'Alert-AGSQLLeaseSignalTimeout', 'SQL Server hosting availability group did not receive a process event signal from the Windows Server Failover Cluster within the lease timeout period.')
,(19422	,'Alert-AGLeaseFailed', 'The renewal of the lease between availability group and the Windows Server Failover Cluster failed.')
,(19423	,'Alert-AGLeaseInvalid', 'The lease of availability group is no longer valid to start the lease renewal process.')
,(35217	,'Alert-AGThreadStarvation', 'The thread pool for Always On Availability Groups was unable to start a new worker thread.')
,(35256	,'Alert-AGSessionTimeout', 'The session timeout value was exceeded while waiting for a response from the other availability replica.')
,(35264	,'Alert-AGSuspended', 'Always On Availability Groups data movement for database has been suspended.')
,(35265	,'Alert-AGResumed', 'Always On Availability Groups data movement for database has been resumed.')
,(41402	,'Alert-AGClusterOffline', 'The WSFC cluster is offline, and this availability group is not available.')
,(41403	,'Alert-AGOffline1', 'Availability group is offline.')
,(41404	,'Alert-AGOffline2', 'The availability group is offline, and is unavailable.')
,(41407	,'Alert-AGNotSynchronizing1', 'Some availability replicas are not synchronizing data.')
,(41408	,'Alert-AGNotSynchronizing2', 'In this availability group, at least one secondary replica has a NOT SYNCHRONIZING.')
,(41411	,'Alert-AGReplicaNotHealthy', 'Some availability replicas do not have a healthy role.')
,(41413	,'Alert-AGDisconnected1', 'Some availability replicas are disconnected.')
,(41414	,'Alert-AGDisconnected2', 'In this availability group, at least one secondary replica is not connected to the primary replica.')
,(41415	,'Alert-AGNotHealthy', 'Availability replica does not have a healthy role.')
,(41417	,'Alert-AGDisconnected3', 'Availability replica is disconnected.')
,(41419	,'Alert-AGDatabaseNotHealthy1', 'Data synchronization state of some availability database is not healthy.')
,(41420	,'Alert-AGDatabaseNotHealthy2', 'At least one availability database on this availability replica has an unhealthy data synchronization state.')
,(41425	,'Alert-AGDatabaseNotHealthy3', 'Data synchronization state of availability database is not healthy.')
,(41426	,'Alert-AGDatabaseNotHealthy4', 'The data synchronization state of this availability database is unhealthy.')
,(41653	,'Alert-AGDatabaseError', 'One or more database encountered an error causing failure of the availability group.');

--SELECT * FROM @ErrorMessages;

DECLARE ForEachErrorMessage CURSOR LOCAL FAST_FORWARD FOR
SELECT * FROM @ErrorMessages;

OPEN ForEachErrorMessage;
FETCH NEXT FROM ForEachErrorMessage INTO @curErrorNumber, @curAlertName, @curErrorMessage;

WHILE @@FETCH_STATUS = 0
BEGIN
	IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysalerts s WHERE s.message_id = @curErrorNumber)
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