USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-ConcurrentConnections', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'General Statistics|User Connections||>|20000', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-ConcurrentConnections', @operator_name=N'DB.Admin', @notification_method = 1
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TableIntegritySuspect', 
		@message_id=0, 
		@severity=22, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TableIntegritySuspect', @operator_name=N'DB.Admin', @notification_method = 1
GO
USE [msdb]
GO

