USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TempDBVersionStore', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Transactions|Version Store Size (KB)||>|262144000', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TempDBVersionStore', @operator_name=N'DB.Admin', @notification_method = 1
GO
