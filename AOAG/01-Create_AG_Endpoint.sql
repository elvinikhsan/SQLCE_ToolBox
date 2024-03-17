/*** WARNING! This script is intended for PoC Environment! ***/
/*** DO NOT run the script in Production environment without testing! ***/

/***************** PLEASE ENABLE SQLCMD MODE!! ******************/
-- Change the variables values accordingly to match the environment
-- Make sure you have performed the FULL/LOG backup of the database 
-- And restore the database to all secondary replicas WITH NORECOVERY
/****************************************************************/

/* Declare variables */
-- The domain name
:SETVAR DNS ".contoso.com"
-- The nodes name
:SETVAR NODE01 "NODE01"
:SETVAR NODE02 "NODE02"
:SETVAR NODE03 "NODE03"
-- The ip addresses for mirroring endpoint
:SETVAR NODE01IP "10.0.1.1"
:SETVAR NODE02IP "10.0.1.2"
:SETVAR NODE03IP "172.18.0.3"
-- The service account
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
RAISERROR('Adding SQL Server service account to sysadmin role in $(NODE01)...',0,1) WITH NOWAIT;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '$(SQLSERVICE)')
CREATE LOGIN [$(SQLSERVICE)] FROM WINDOWS WITH DEFAULT_DATABASE=[master];
GO
IF IS_SRVROLEMEMBER ('sysadmin', '$(SQLSERVICE)') = 0 
ALTER SERVER ROLE [sysadmin] ADD MEMBER [$(SQLSERVICE)];
GO
ALTER LOGIN [$(SQLSERVICE)] ENABLE;
GO
RAISERROR('Creating mirroring endpoint on $(NODE01)...',0,1) WITH NOWAIT;
GO
DECLARE @mirrorEP AS SYSNAME;
SET @mirrorEP = (SELECT name FROM sys.tcp_endpoints WHERE type_desc = 'DATABASE_MIRRORING')
IF @mirrorEP IS NULL
BEGIN
	CREATE ENDPOINT [AlwaysOn_EP]
	STATE = STARTED AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ($(NODE01IP)))
	FOR DATABASE_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES);

	GRANT CONNECT ON ENDPOINT::[AlwaysOn_EP] TO [$(SQLSERVICE)];
END
ELSE RAISERROR('Database mirroring endpoint already exists...',0,1) WITH NOWAIT;
GO


:CONNECT $(NODE02)
GO
USE master;
GO
RAISERROR('Adding SQL Server service account to sysadmin role in $(NODE02)...',0,1) WITH NOWAIT;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '$(SQLSERVICE)')
CREATE LOGIN [$(SQLSERVICE)] FROM WINDOWS WITH DEFAULT_DATABASE=[master];
GO
IF IS_SRVROLEMEMBER ('sysadmin', '$(SQLSERVICE)') = 0 
ALTER SERVER ROLE [sysadmin] ADD MEMBER [$(SQLSERVICE)];
GO
ALTER LOGIN [$(SQLSERVICE)] ENABLE;
GO
RAISERROR('Creating mirroring endpoint on $(NODE02)...',0,1) WITH NOWAIT;
GO
DECLARE @mirrorEP AS SYSNAME;
SET @mirrorEP = (SELECT name FROM sys.tcp_endpoints WHERE type_desc = 'DATABASE_MIRRORING')
IF @mirrorEP IS NULL
BEGIN
	CREATE ENDPOINT [AlwaysOn_EP]
	STATE = STARTED AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ($(NODE02IP)))
	FOR DATABASE_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES);

	GRANT CONNECT ON ENDPOINT::[AlwaysOn_EP] TO [$(SQLSERVICE)];
END
ELSE RAISERROR('Database mirroring endpoint already exists...',0,1) WITH NOWAIT;
GO
:CONNECT $(NODE03)
GO
USE master;
GO
RAISERROR('Adding SQL Server service account to sysadmin role in $(NODE03)...',0,1) WITH NOWAIT;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '$(SQLSERVICE)')
CREATE LOGIN [$(SQLSERVICE)] FROM WINDOWS WITH DEFAULT_DATABASE=[master];
GO
IF IS_SRVROLEMEMBER ('sysadmin', '$(SQLSERVICE)') = 0 
ALTER SERVER ROLE [sysadmin] ADD MEMBER [$(SQLSERVICE)];
GO
ALTER LOGIN [$(SQLSERVICE)] ENABLE;
GO
RAISERROR('Creating mirroring endpoint on $(NODE03)...',0,1) WITH NOWAIT;
GO
DECLARE @mirrorEP AS SYSNAME;
SET @mirrorEP = (SELECT name FROM sys.tcp_endpoints WHERE type_desc = 'DATABASE_MIRRORING')
IF @mirrorEP IS NULL
BEGIN
	CREATE ENDPOINT [AlwaysOn_EP]
	STATE = STARTED AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ($(NODE03IP)))
	FOR DATABASE_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES);

	GRANT CONNECT ON ENDPOINT::[AlwaysOn_EP] TO [$(SQLSERVICE)];
END
ELSE RAISERROR('Database mirroring endpoint already exists...',0,1) WITH NOWAIT;
GO
/* Enable/start XEvent AlwaysOn */
:CONNECT $(NODE01)
RAISERROR('Enabling always on xevent session on $(NODE01)...',0,1) WITH NOWAIT;
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
RAISERROR('Enabling always on xevent session on $(NODE02)...',0,1) WITH NOWAIT;
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
RAISERROR('Enabling always on xevent session on $(NODE03)...',0,1) WITH NOWAIT;
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