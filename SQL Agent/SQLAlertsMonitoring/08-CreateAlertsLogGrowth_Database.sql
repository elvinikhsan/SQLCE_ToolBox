USE [msdb]
GO
-- Change database name accordingly
-- Repeat for all databases
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TlogGrowth80PctUsed-DatabaseName', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Percent Log Used|DatabaseName|>|80', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TlogGrowth80PctUsed-DatabaseName', @operator_name=N'DB.Admin', @notification_method = 1
GO
