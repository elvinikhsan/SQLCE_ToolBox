USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-LongRunningTransaction', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Transactions|Longest Transaction Running Time||=|60', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LongRunningTransaction', @operator_name=N'DB.Admin', @notification_method = 1
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

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LockRequestSec', @operator_name=N'DB.Admin', @notification_method = 1
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

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-LocksAvgWaitTime', @operator_name=N'DB.Admin', @notification_method = 1
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

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-MemoryGrantPending', @operator_name=N'DB.Admin', @notification_method = 1
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

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-NumberDeadlocks', @operator_name=N'DB.Admin', @notification_method = 1
GO

USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-BufferCacheHitRatio', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Buffer Manager|Buffer cache hit ratio||<|0.95', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-BufferCacheHitRatio', @operator_name=N'DB.Admin', @notification_method = 1
GO

/****** Object:  Alert [Alert-PageLifeExpectancy]    Script Date: 06/17/2013 12:11:24 ******/
EXEC msdb.dbo.sp_add_alert @name=N'Alert-PageLifeExpectancy', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'SQLServer:Buffer Manager|Page life expectancy||<|10000', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-PageLifeExpectancy', @operator_name=N'DB.Admin', @notification_method = 1
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
		@performance_condition=N'SQLServer:General Statistics|Processes blocked||>|5', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-ProcessBlocked', @operator_name=N'DB.Admin', @notification_method = 1
GO

USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'Alert-TempDBFreeSpace', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@performance_condition=N'Transactions|Free Space in tempdb (KB)||<|10485760', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-TempDBFreeSpace', @operator_name=N'DB.Admin', @notification_method = 1
GO