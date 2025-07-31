USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LogFileSize-iSeller_Livin_System', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Log File(s) Size (KB)|iSeller_Livin_System|>|1073741824', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LogFileSize-iSeller_Livin_System', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LogFileSize-Settlement', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Log File(s) Size (KB)|Settlement|>|1073741824', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LogFileSize-Settlement', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LogFileSize-Tenant', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Log File(s) Size (KB)|Tenant|>|1073741824', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LogFileSize-Tenant', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LogFileSize-tempdb', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Log File(s) Size (KB)|tempdb|>|1073741824', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LogFileSize-tempdb', @operator_name=N'DB.Admin', @notification_method = 1
GO