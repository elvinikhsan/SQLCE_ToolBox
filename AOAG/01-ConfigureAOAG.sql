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
:SETVAR NODE1 "NODE1"
:SETVAR NODE2 "NODE2"
:SETVAR NODE3 "NODE3"
-- the ip addresses for mirroring endpoint
:SETVAR NODE1IP "10.0.1.1"
:SETVAR NODE2IP "10.0.1.2"
:SETVAR NODE3IP "172.18.0.3"
-- the service account
:SETVAR SQLSERVICE "CONTOSO\sqlserversvc"

PRINT 'Set SQLCMD variables done!';
GO

SELECT '$(DNS)' AS dns_name, '$(SQLSERVICE)' AS sqlservice_account,
	   '$(NODE1)' AS node1, '$(NODE1)$(DNS)' AS node1_fqdn, '$(NODE1IP)' AS node1_ip, 
	   '$(NODE2)' AS node2, '$(NODE2)$(DNS)' AS node2_fqdn, '$(NODE2IP)' AS node2_ip, 
	   '$(NODE3)' AS node3, '$(NODE3)$(DNS)' AS node3_fqdn, '$(NODE3IP)' AS node3_ip;
GO

/* test connection to each node */
-- NODE3
:CONNECT $(NODE3)
GO
SELECT @@SERVERNAME AS instance_name;
GO
-- NODE2
:CONNECT $(NODE2) 
GO
SELECT @@SERVERNAME AS instance_name;
GO
-- NODE1 AS PRIMARY
:CONNECT $(NODE1)
GO
SELECT @@SERVERNAME AS instance_name;
GO
/* Create replication end point */
USE master;
GO
RAISERROR('Creating mirroring endpoint on NODE1...',0,1) WITH NOWAIT;
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
STATE = STARTED AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ($(NODE1IP)))
FOR DATABASE_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES);
GO
GRANT CONNECT ON ENDPOINT::[AlwaysOn_EP] TO [$(SQLSERVICE)];
GO

:CONNECT $(NODE2)
GO
USE master;
GO
RAISERROR('Creating mirroring endpoint on NODE2...',0,1) WITH NOWAIT;
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
STATE = STARTED AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ($(NODE2IP)))
FOR DATABASE_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES);
GO
GRANT CONNECT ON ENDPOINT::[AlwaysOn_EP] TO [$(SQLSERVICE)];
GO
:CONNECT $(NODE3)
GO
USE master;
GO
RAISERROR('Creating mirroring endpoint on NODE3...',0,1) WITH NOWAIT;
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
STATE = STARTED AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ($(NODE3IP)))
FOR DATABASE_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES);
GO
GRANT CONNECT ON ENDPOINT::[AlwaysOn_EP] TO [$(SQLSERVICE)];
GO
/* Enable/start XEvent AlwaysOn */
:CONNECT $(NODE1)
RAISERROR('Enabling always on xevent session on NODE1...',0,1) WITH NOWAIT;
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
:CONNECT $(NODE2)
RAISERROR('Enabling always on xevent session on NODE2...',0,1) WITH NOWAIT;
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
:CONNECT $(NODE3)
RAISERROR('Enabling always on xevent session on NODE3...',0,1) WITH NOWAIT;
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
