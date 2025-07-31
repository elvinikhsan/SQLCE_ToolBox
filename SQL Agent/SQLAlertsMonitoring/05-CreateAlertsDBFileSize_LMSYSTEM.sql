USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize-iSeller_Livin_System', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Data File(s) Size (KB)|iSeller_Livin_System|>|16106127360', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize-iSeller_Livin_System', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize-Settlement', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Data File(s) Size (KB)|Settlement|>|16106127360', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize-Settlement', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize-Tenant', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Data File(s) Size (KB)|Tenant|>|16106127360', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize-Tenant', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize-tempdb', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Data File(s) Size (KB)|tempdb|>|16106127360', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize-tempdb', @operator_name=N'DB.Admin', @notification_method = 1
GO