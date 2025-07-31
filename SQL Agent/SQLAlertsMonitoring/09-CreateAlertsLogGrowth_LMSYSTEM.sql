USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TlogGrowth80PctUsed-iSeller_Livin_System', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Percent Log Used|iSeller_Livin_System|>|80', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TlogGrowth80PctUsed-iSeller_Livin_System', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TlogGrowth80PctUsed-Settlement', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Percent Log Used|Settlement|>|80', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TlogGrowth80PctUsed-Settlement', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TlogGrowth80PctUsed-Tenant', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Percent Log Used|Tenant|>|80', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TlogGrowth80PctUsed-Tenant', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TlogGrowth80PctUsed-tempdb', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Percent Log Used|tempdb|>|80', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TlogGrowth80PctUsed-tempdb', @operator_name=N'DB.Admin', @notification_method = 1
GO