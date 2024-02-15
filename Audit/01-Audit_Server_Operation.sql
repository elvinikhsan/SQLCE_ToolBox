USE [master]
GO
CREATE SERVER AUDIT [Audit_Server_Operation]
TO FILE 
(	FILEPATH = N'C:\Audit\'
	,MAXSIZE = 10 MB
	,MAX_FILES = 5
	,RESERVE_DISK_SPACE = ON
) WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE)
ALTER SERVER AUDIT [Audit_Server_Operation] WITH (STATE = ON)
GO
CREATE DATABASE AUDIT SPECIFICATION [Audit_Master_Server_Operation]
FOR SERVER AUDIT [Audit_Server_Operation]
/* Linked Server */
ADD (EXECUTE ON OBJECT::[sys].[sp_addlinkedserver] BY [dbo]),
ADD (EXECUTE ON OBJECT::[sys].[sp_addlinkedsrvlogin] BY [dbo]),
ADD (EXECUTE ON OBJECT::[sys].[sp_droplinkedsrvlogin] BY [dbo]),
ADD (EXECUTE ON OBJECT::[sys].[sp_addlinkedserver] BY [dbo]),
ADD (EXECUTE ON OBJECT::[sys].[sp_addserver] BY [dbo]),
ADD (EXECUTE ON OBJECT::[sys].[sp_dropserver] BY [dbo]),
ADD (EXECUTE ON OBJECT::[sys].[sp_serveroption] BY [dbo]),
ADD (EXECUTE ON OBJECT::[sys].[sp_setnetname] BY [dbo]),
/* Configuration */
ADD (EXECUTE ON OBJECT::[sys].[sp_configure] BY [dbo])
WITH (STATE = ON)
GO
USE [msdb]
GO
CREATE DATABASE AUDIT SPECIFICATION [Audit_MSDB_Server_Operation]
FOR SERVER AUDIT [Audit_Server_Operation]
/* Agent Jobs */
ADD (EXECUTE ON OBJECT::[dbo].[sp_add_schedule] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_add_jobstep] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_update_jobstep] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_update_jobschedule] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_delete_jobschedule] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_add_job] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_update_job] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_delete_job] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_stop_job] BY [dbo])
WITH (STATE = ON)
GO