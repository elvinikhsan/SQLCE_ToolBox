USE [msdb]
GO
-- All databases
EXEC msdb.dbo.sp_add_alert @name=N'Alert-DataFileAutoGrow', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@notification_message=N'Database data file auto grow event is detected!', 
		@wmi_namespace=N'\\.\root\Microsoft\SqlServer\ServerEvents\MSSQLSERVER', 
		@wmi_query=N'SELECT * FROM DATA_FILE_AUTO_GROW', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-DataFileAutoGrow', @operator_name=N'DB.Admin', @notification_method = 1
GO

USE [msdb]
GO
-- Specific database >> Replace Database_Name accordingly
EXEC msdb.dbo.sp_add_alert @name=N'Alert-Database_Name-DataFileGrow', 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@wmi_namespace=N'\\.\root\Microsoft\SqlServer\ServerEvents\MSSQLSERVER', 
		@wmi_query=N'SELECT * FROM DATABASE_FILE_SIZE_CHANGE WHERE DatabaseName = ''Database_Name'' AND State = 1', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Alert-Database_Name-DataFileGrow', @operator_name=N'DB.Admin', @notification_method = 1
GO