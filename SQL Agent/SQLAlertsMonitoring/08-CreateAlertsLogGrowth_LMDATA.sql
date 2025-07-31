USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TlogGrowth80PctUsed-iSellerStore_living1', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Percent Log Used|iSellerStore_living1|>|80', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TlogGrowth80PctUsed-iSellerStore_living1', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TlogGrowth80PctUsed-CompanyOnboarding', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Percent Log Used|CompanyOnboarding|>|80', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TlogGrowth80PctUsed-CompanyOnboarding', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TlogGrowth80PctUsed-FileTransfer', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Percent Log Used|FileTransfer|>|80', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TlogGrowth80PctUsed-FileTransfer', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TlogGrowth80PctUsed-HangfireScheduler', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Percent Log Used|HangfireScheduler|>|80', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TlogGrowth80PctUsed-HangfireScheduler', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TlogGrowth80PctUsed-Lending', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Percent Log Used|Lending|>|80', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TlogGrowth80PctUsed-Lending', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TlogGrowth80PctUsed-OnboardingIndividu', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Percent Log Used|OnboardingIndividu|>|80', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TlogGrowth80PctUsed-OnboardingIndividu', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TlogGrowth80PctUsed-OnboardingIndividu_Data', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Percent Log Used|OnboardingIndividu_Data|>|80', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TlogGrowth80PctUsed-OnboardingIndividu_Data', @operator_name=N'DB.Admin', @notification_method = 1
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TlogGrowth80PctUsed-Ordering', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Databases|Percent Log Used|Ordering|>|80', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TlogGrowth80PctUsed-Ordering', @operator_name=N'DB.Admin', @notification_method = 1
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