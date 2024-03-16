/*** WARNING! This script is only for new AG installation only!! ***/
/*** DO NOT use the script on an already running AG environment! ***/

/***************** PLEASE ENABLE SQLCMD MODE!! ******************/
-- make sure to change the variables values accordingly
-- make sure you have performed the FULL backup of the database
/****************************************************************/
/* Declare variables */
-- the domain name
:SETVAR DNS ".contoso.com"
-- the nodes name
:SETVAR NODE01 "NODE01"
:SETVAR NODE02 "NODE02"
:SETVAR NODE03 "NODE03"
-- the ip addresses for mirroring endpoint
:SETVAR NODE01IP "10.0.1.1"
:SETVAR NODE02IP "10.0.1.2"
:SETVAR NODE03IP "172.18.0.3"
-- the service account
:SETVAR SQLSERVICE "CONTOSO\sqlservice"

PRINT 'Set SQLCMD variables done!';
GO

SELECT '$(DNS)' AS dns_name, '$(SQLSERVICE)' AS sqlservice_account,
	   '$(NODE01)' AS NODE01, '$(NODE01)$(DNS)' AS NODE01_fqdn, '$(NODE01IP)' AS NODE01_ip, 
	   '$(NODE02)' AS NODE02, '$(NODE02)$(DNS)' AS NODE02_fqdn, '$(NODE02IP)' AS NODE02_ip, 
	   '$(NODE03)' AS NODE03, '$(NODE03)$(DNS)' AS NODE03_fqdn, '$(NODE03IP)' AS NODE03_ip;
GO

/* test connection to each node */
-- NODE03
:CONNECT $(NODE03)
GO
SELECT @@SERVERNAME AS instance_name;
GO
-- NODE02
:CONNECT $(NODE02) 
GO
SELECT @@SERVERNAME AS instance_name;
GO
-- NODE01 AS PRIMARY
:CONNECT $(NODE01)
GO
SELECT @@SERVERNAME AS instance_name;
GO
/* Create replication end point */
USE master;
GO
RAISERROR('Creating mirroring endpoint on NODE01...',0,1) WITH NOWAIT;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '$(SQLSERVICE)')
CREATE LOGIN [$(SQLSERVICE)] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [$(SQLSERVICE)];
GO
ALTER LOGIN [$(SQLSERVICE)] ENABLE
GO
IF EXISTS ( SELECT * FROM sys.tcp_endpoints WHERE name = 'AlwaysOn_EP')
DROP ENDPOINT AlwaysOn_EP;
GO
CREATE ENDPOINT [AlwaysOn_EP]
STATE = STARTED AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ($(NODE01IP)))
FOR DATABASE_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES);
GO
GRANT CONNECT ON ENDPOINT::[AlwaysOn_EP] TO [$(SQLSERVICE)];
GO

:CONNECT $(NODE02)
GO
USE master;
GO
RAISERROR('Creating mirroring endpoint on NODE02...',0,1) WITH NOWAIT;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '$(SQLSERVICE)')
CREATE LOGIN [$(SQLSERVICE)] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [$(SQLSERVICE)];
GO
ALTER LOGIN [$(SQLSERVICE)] ENABLE
GO
IF EXISTS ( SELECT * FROM sys.tcp_endpoints WHERE name = 'AlwaysOn_EP')
DROP ENDPOINT AlwaysOn_EP;
GO
CREATE ENDPOINT [AlwaysOn_EP]
STATE = STARTED AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ($(NODE02IP)))
FOR DATABASE_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES);
GO
GRANT CONNECT ON ENDPOINT::[AlwaysOn_EP] TO [$(SQLSERVICE)];
GO
:CONNECT $(NODE03)
GO
USE master;
GO
RAISERROR('Creating mirroring endpoint on NODE03...',0,1) WITH NOWAIT;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '$(SQLSERVICE)')
CREATE LOGIN [$(SQLSERVICE)] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [$(SQLSERVICE)];
GO
ALTER LOGIN [$(SQLSERVICE)] ENABLE
GO
IF EXISTS ( SELECT * FROM sys.tcp_endpoints WHERE name = 'AlwaysOn_EP')
DROP ENDPOINT AlwaysOn_EP;
GO
CREATE ENDPOINT [AlwaysOn_EP]
STATE = STARTED AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ($(NODE03IP)))
FOR DATABASE_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES);
GO
GRANT CONNECT ON ENDPOINT::[AlwaysOn_EP] TO [$(SQLSERVICE)];
GO
/* Enable/start XEvent AlwaysOn */
:CONNECT $(NODE01)
RAISERROR('Enabling always on xevent session on NODE01...',0,1) WITH NOWAIT;
GO
IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='AlwaysOn_health')
BEGIN
ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE=ON);
END
IF NOT EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name='AlwaysOn_health')
BEGIN
ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START;
END
GO
:CONNECT $(NODE02)
RAISERROR('Enabling always on xevent session on NODE02...',0,1) WITH NOWAIT;
GO
IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='AlwaysOn_health')
BEGIN
ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE=ON);
END
IF NOT EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name='AlwaysOn_health')
BEGIN
ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START;
END
GO
:CONNECT $(NODE03)
RAISERROR('Enabling always on xevent session on NODE03...',0,1) WITH NOWAIT;
GO
IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='AlwaysOn_health')
BEGIN
ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE=ON);
END
IF NOT EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name='AlwaysOn_health')
BEGIN
ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START;
END
GO