USE [msdb]
GO

/****** Object:  Alert [Alert-DataFileSize]    Script Date: 06/17/2013 11:59:12 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileSize', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'SQLServer:Databases|Data File(s) Size (KB)|_Total|>|209715200', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileSize', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
GO


USE [msdb]
GO

/****** Object:  Alert [Alert-FatalError]    Script Date: 06/17/2013 11:59:20 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-FatalError', 
		@message_id=0, 
		@severity=25, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-FatalError', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
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

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-FatalErrorHardware', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
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

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-FatalErrorInCurrentProcess', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
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

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-FatalErrorInDBIntegrity', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
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

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-FatalErrorInDBProcess', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
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

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-FatalErrorInResources', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
GO


USE [msdb]
GO

/****** Object:  Alert [Alert-FreePages]    Script Date: 06/17/2013 12:08:23 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-FreePages', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'SQLServer:Buffer Manager|Free pages||<|320', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-FreePages', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
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

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-InsufficientResources', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
GO

USE [msdb]
GO

/****** Object:  Alert [Alert-LockRequestSec]    Script Date: 06/17/2013 12:09:19 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LockRequestSec', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'SQLServer:Locks|Lock Requests/sec|_Total|>|1000', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LockRequestSec', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
GO

USE [msdb]
GO

/****** Object:  Alert [Alert-LocksAvgWaitTime]    Script Date: 06/17/2013 12:09:42 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LocksAvgWaitTime', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'SQLServer:Locks|Average Wait Time (ms)|_Total|>|500', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LocksAvgWaitTime', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
GO


USE [msdb]
GO

/****** Object:  Alert [Alert-LogFileSize]    Script Date: 06/17/2013 12:10:07 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LogFileSize', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'SQLServer:Databases|Log File(s) Size (KB)|_Total|>|5242880', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LogFileSize', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
GO


USE [msdb]
GO

/****** Object:  Alert [Alert-MemoryGrantPending]    Script Date: 06/17/2013 12:10:36 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-MemoryGrantPending', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'SQLServer:Memory Manager|Memory Grants Pending||>|0', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-MemoryGrantPending', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
GO

USE [msdb]
GO

/****** Object:  Alert [Alert-NumberDeadlocks]    Script Date: 06/17/2013 12:11:01 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-NumberDeadlocks', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'SQLServer:Locks|Number of Deadlocks/sec|_Total|=|1', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-NumberDeadlocks', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
GO

USE [msdb]
GO

/****** Object:  Alert [Alert-PageLifeExpectancy]    Script Date: 06/17/2013 12:11:24 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-PageLifeExpectancy', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'SQLServer:Buffer Manager|Page life expectancy||<|300', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-PageLifeExpectancy', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
GO

USE [msdb]
GO

/****** Object:  Alert [Alert-ProcessBlocked]    Script Date: 06/17/2013 12:11:46 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-ProcessBlocked', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'SQLServer:General Statistics|Processes blocked||>|10', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-ProcessBlocked', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
GO

--USE [msdb]
--GO

--/****** Object:  Alert [Alert-WorktableCacheRatio]    Script Date: 06/17/2013 12:12:13 ******/
--EXEC msdb.dbo.sp_add_alert @name=N'Alert-WorktableCacheRatio', 
--		@message_id=0, 
--		@severity=0, 
--		@enabled=0, 
--		@delay_between_responses=300, 
--		@include_event_description_in=1, 
--		@category_name=N'[Uncategorized]', 
--		@performance_condition=N'SQLServer:Access Methods|Worktables From Cache Ratio||<|90', 
--		@job_id=N'00000000-0000-0000-0000-000000000000'
--GO

--EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-WorktableCacheRatio', @operator_name=N'Elvin.Ikhsan', @notification_method = 1
--GO

