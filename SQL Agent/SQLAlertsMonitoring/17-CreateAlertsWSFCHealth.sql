use master;
GO
SET NOCOUNT ON;

DECLARE @curAlertName SYSNAME
      , @curEventId INT
	  , @curEventMessage NVARCHAR(MAX)
	  , @wmiQuery NVARCHAR(512)
      , @operatorName SYSNAME = N'John.Doe'
	  , @wmiNamespace SYSNAME = N'\\.\root\cimv2';

DECLARE @ClusterEvents TABLE (EventId INT, AlertName NVARCHAR(50), EventMessage NVARCHAR(MAX));

INSERT INTO @ClusterEvents
VALUES (1069	,'Alert-WSFCResourceFailed', 'Cluster resource in clustered role failed.')
,(1135	,'Alert-WSFCNodeRemoved', 'Cluster node was removed from the active failover cluster membership.')
,(1177	,'Alert-WSFCQuorumLost', 'The Cluster service is shutting down because quorum was lost.')
,(1205	,'Alert-WSFCRoleNotOnline', 'The Cluster service failed to bring a clustered role completely online or offline.')
,(1254	,'Alert-WSFCFailoverThreshold', 'Clustered role has exceeded its failover threshold and was left in a failed state.')
,(1146	,'Alert-WSFCRHSTerminated', 'The cluster Resource Hosting Subsystem (RHS) process was terminated and will be restarted.')
,(1230	,'Alert-WSFCRHSDeadlock', 'A cluster resource did not respond in a timely fashion; RHS deadlock detected.')
,(1038	,'Alert-WSFCDiskOwnershipLost', 'Ownership of a cluster shared disk has been unexpectedly lost by this node.')
,(1127	,'Alert-WSFCInterfaceFailed', 'Cluster network interface for a node has failed.')
,(1129	,'Alert-WSFCNetworkPartitioned', 'Cluster network is partitioned; some attached nodes cannot communicate.')
,(1130	,'Alert-WSFCNetworkDown', 'Cluster network is down.');

--SELECT * FROM @ClusterEvents;

DECLARE ForEachClusterEvent CURSOR LOCAL FAST_FORWARD FOR
SELECT * FROM @ClusterEvents;

OPEN ForEachClusterEvent;
FETCH NEXT FROM ForEachClusterEvent INTO @curEventId, @curAlertName, @curEventMessage;

WHILE @@FETCH_STATUS = 0
BEGIN
	IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysalerts s WHERE s.name = @curAlertName)
	BEGIN 
		SET @wmiQuery = N'SELECT * FROM __InstanceCreationEvent WHERE TargetInstance ISA ''Win32_NTLogEvent'''
					  + N' AND TargetInstance.Logfile = ''System'''
					  + N' AND TargetInstance.SourceName = ''Microsoft-Windows-FailoverClustering'''
					  + N' AND TargetInstance.EventCode = ' + CAST(@curEventId AS NVARCHAR(10));

		EXECUTE msdb.dbo.sp_add_alert 
				@name = @curAlertName
			  , @enabled = 1 
			  , @delay_between_responses = 300 
			  , @include_event_description_in = 1 
			  , @notification_message = @curEventMessage
			  , @wmi_namespace = @wmiNamespace
			  , @wmi_query = @wmiQuery
			  , @job_id = N'00000000-0000-0000-0000-000000000000';

		EXECUTE msdb.dbo.sp_add_notification @alert_name= @curAlertName, @operator_name= @operatorName, @notification_method = 1;

        RAISERROR('WMI alert ''%s'' for cluster event ID %d is created.', -1, -1, @curAlertName, @curEventId) WITH NOWAIT;
    END

	FETCH NEXT FROM ForEachClusterEvent INTO @curEventId, @curAlertName, @curEventMessage;
END

CLOSE ForEachClusterEvent;
DEALLOCATE ForEachClusterEvent;
