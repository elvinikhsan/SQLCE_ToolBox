USE msdb
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-FatalError', 
		@message_id=0, 
		@severity=25, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-FatalError', @operator_name=N'DB.Admin', @notification_method = 1
GO

USE [msdb]
GO

/****** Object:  Alert [Alert-FatalErrorHardware]    Script Date: 06/17/2013 11:59:31 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-FatalErrorHardware', 
		@message_id=0, 
		@severity=24, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-FatalErrorHardware', @operator_name=N'DB.Admin', @notification_method = 1
GO

USE [msdb]
GO

/****** Object:  Alert [Alert-FatalErrorInCurrentProcess]    Script Date: 06/17/2013 11:59:44 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-FatalErrorInCurrentProcess', 
		@message_id=0, 
		@severity=20, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-FatalErrorInCurrentProcess', @operator_name=N'DB.Admin', @notification_method = 1
GO

USE [msdb]
GO

/****** Object:  Alert [Alert-FatalErrorInDBIntegrity]    Script Date: 06/17/2013 12:00:11 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-FatalErrorInDBIntegrity', 
		@message_id=0, 
		@severity=23, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-FatalErrorInDBIntegrity', @operator_name=N'DB.Admin', @notification_method = 1
GO

USE [msdb]
GO

/****** Object:  Alert [Alert-FatalErrorInDBProcess]    Script Date: 06/17/2013 12:00:22 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-FatalErrorInDBProcess', 
		@message_id=0, 
		@severity=21, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-FatalErrorInDBProcess', @operator_name=N'DB.Admin', @notification_method = 1
GO

USE [msdb]
GO

/****** Object:  Alert [Alert-FatalErrorInResources]    Script Date: 06/17/2013 12:07:59 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-FatalErrorInResources', 
		@message_id=0, 
		@severity=19, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-FatalErrorInResources', @operator_name=N'DB.Admin', @notification_method = 1
GO

USE [msdb]
GO

/****** Object:  Alert [Alert-InsufficientResources]    Script Date: 06/17/2013 12:08:50 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-InsufficientResources', 
		@message_id=0, 
		@severity=17, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-InsufficientResources', @operator_name=N'DB.Admin', @notification_method = 1
GO