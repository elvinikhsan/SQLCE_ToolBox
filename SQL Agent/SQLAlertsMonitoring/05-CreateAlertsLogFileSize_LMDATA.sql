USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LogFileSize-iSellerStore_living1', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Log File(s) Size (KB)|iSellerStore_living1|>|1073741824', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LogFileSize-iSellerStore_living1', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LogFileSize-CompanyOnboarding', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Log File(s) Size (KB)|CompanyOnboarding|>|1073741824', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LogFileSize-CompanyOnboarding', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LogFileSize-FileTransfer', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Log File(s) Size (KB)|FileTransfer|>|1073741824', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LogFileSize-FileTransfer', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LogFileSize-HangfireScheduler', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Log File(s) Size (KB)|HangfireScheduler|>|1073741824', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LogFileSize-HangfireScheduler', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LogFileSize-Lending', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Log File(s) Size (KB)|Lending|>|1073741824', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LogFileSize-Lending', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LogFileSize-OnboardingIndividu', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Log File(s) Size (KB)|OnboardingIndividu|>|1073741824', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LogFileSize-OnboardingIndividu', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LogFileSize-OnboardingIndividu_Data', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Log File(s) Size (KB)|OnboardingIndividu_Data|>|1073741824', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LogFileSize-OnboardingIndividu_Data', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LogFileSize-Ordering', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Log File(s) Size (KB)|Ordering|>|1073741824', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LogFileSize-Ordering', @operator_name=N'DB.Admin', @notification_method = 1
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