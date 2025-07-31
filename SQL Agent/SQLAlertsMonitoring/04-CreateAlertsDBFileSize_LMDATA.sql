USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize-iSellerStore_living1', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Data File(s) Size (KB)|iSellerStore_living1|>|16106127360', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize-iSellerStore_living1', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize-CompanyOnboarding', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Data File(s) Size (KB)|CompanyOnboarding|>|16106127360', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize-CompanyOnboarding', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize-FileTransfer', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Data File(s) Size (KB)|FileTransfer|>|16106127360', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize-FileTransfer', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize-HangfireScheduler', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Data File(s) Size (KB)|HangfireScheduler|>|16106127360', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize-HangfireScheduler', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize-Lending', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Data File(s) Size (KB)|Lending|>|16106127360', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize-Lending', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize-OnboardingIndividu', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Data File(s) Size (KB)|OnboardingIndividu|>|16106127360', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize-OnboardingIndividu', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize-OnboardingIndividu_Data', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Data File(s) Size (KB)|OnboardingIndividu_Data|>|16106127360', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize-OnboardingIndividu_Data', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize-Ordering', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Data File(s) Size (KB)|Ordering|>|16106127360', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize-Ordering', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize-tempdb', 
		@enabled=1, 
		@delay_between_responses=3600, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Data File(s) Size (KB)|tempdb|>|16106127360', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize-tempdb', @operator_name=N'DB.Admin', @notification_method = 1
GO