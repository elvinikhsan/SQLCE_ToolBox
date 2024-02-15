USE [master]
GO
CREATE SERVER AUDIT [Audit_Schema_Change]
TO FILE 
(	FILEPATH = N'C:\Audit\'
	,MAXSIZE = 10 MB
	,MAX_FILES = 5
	,RESERVE_DISK_SPACE = ON
) WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE)
ALTER SERVER AUDIT [Audit_Schema_Change] WITH (STATE = ON)
GO
CREATE SERVER AUDIT SPECIFICATION [Audit_Spec_Schema_Change]
FOR SERVER AUDIT [Audit_Schema_Change]
ADD (SCHEMA_OBJECT_CHANGE_GROUP)
WITH (STATE = ON)
GO



