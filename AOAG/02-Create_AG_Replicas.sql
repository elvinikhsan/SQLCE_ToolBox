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
-- The AG name
:SETVAR AGNAME "AOAG01"
-- The database name
:SETVAR DBNAME "DUMMYDB"

PRINT 'Set SQLCMD variables done!';
GO

SELECT '$(DNS)' AS dns_name,'$(AGNAME)' AS ag_name, '$(DBNAME)' AS dbs_name,
	   '$(NODE01)' AS NODE01, '$(NODE01)$(DNS)' AS NODE01_fqdn, '$(NODE01IP)' AS NODE01_ip, 
	   '$(NODE02)' AS NODE02, '$(NODE02)$(DNS)' AS NODE02_fqdn, '$(NODE02IP)' AS NODE02_ip, 
	   '$(NODE03)' AS NODE03, '$(NODE03)$(DNS)' AS NODE03_fqdn, '$(NODE03IP)' AS NODE03_ip;
GO
/* Create availability group */
-- Here we connect to our primary replica (NODE01) and create our AG. */
:CONNECT $(NODE01)
GO
USE [master]
GO
RAISERROR('Creating always on availability group $(AGNAME)...',0,1) WITH NOWAIT;
GO
DECLARE @sqlStr NVARCHAR(MAX);
DECLARE @mirrorTcpPort AS INT;
SET @mirrorTcpPort = (SELECT port FROM sys.tcp_endpoints WHERE type_desc = 'DATABASE_MIRRORING');
IF @mirrorTcpPort IS NULL THROW 50000, 'There is no mirroring endpoint!',16;

SET @sqlStr = N'CREATE AVAILABILITY GROUP [$(AGNAME)] ';
SET @sqlStr = @sqlStr + N'WITH (AUTOMATED_BACKUP_PREFERENCE = SECONDARY,DB_FAILOVER = ON, DTC_SUPPORT = PER_DB, FAILURE_CONDITION_LEVEL = 2, HEALTH_CHECK_TIMEOUT = 60000, CLUSTER_TYPE = WSFC) ';
SET @sqlStr = @sqlStr + N'FOR DATABASE [$(DBNAME)] ';
SET @sqlStr = @sqlStr + N'REPLICA ON N''$(NODE01)'' WITH (ENDPOINT_URL = N''TCP://$(NODE01)$(DNS):' + CAST(@mirrorTcpPort AS NVARCHAR) + N'''' + N', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, SESSION_TIMEOUT = 20, BACKUP_PRIORITY = 50, SEEDING_MODE = MANUAL, PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL), SECONDARY_ROLE(ALLOW_CONNECTIONS = ALL)), ';
SET @sqlStr = @sqlStr + N'N''$(NODE02)'' WITH (ENDPOINT_URL = N''TCP://$(NODE02)$(DNS):' + CAST(@mirrorTcpPort AS NVARCHAR) + N'''' + N', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, SESSION_TIMEOUT = 20, BACKUP_PRIORITY = 40, SEEDING_MODE = MANUAL, PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL), SECONDARY_ROLE(ALLOW_CONNECTIONS = ALL)), ';
SET @sqlStr = @sqlStr + N'N''$(NODE03)'' WITH (ENDPOINT_URL = N''TCP://$(NODE03)$(DNS):' + CAST(@mirrorTcpPort AS NVARCHAR) + N'''' + N', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, SESSION_TIMEOUT = 20, BACKUP_PRIORITY = 60, SEEDING_MODE = MANUAL, PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL), SECONDARY_ROLE(ALLOW_CONNECTIONS = ALL)); ';

--PRINT @sqlStr;

EXEC sp_executesql @sqlStr;
GO
RAISERROR('Always on avaibility group created...',0,1) WITH NOWAIT;
GO
:CONNECT $(NODE02)
RAISERROR('Joining $(NODE02)...',0,1) WITH NOWAIT;
GO
ALTER AVAILABILITY GROUP [$(AGNAME)] JOIN;
GO
ALTER AVAILABILITY GROUP [$(AGNAME)] GRANT CREATE ANY DATABASE;
GO
:CONNECT $(NODE03)
RAISERROR('Joining $(NODE03)...',0,1) WITH NOWAIT;
GO
ALTER AVAILABILITY GROUP [$(AGNAME)] JOIN;
GO
ALTER AVAILABILITY GROUP [$(AGNAME)] GRANT CREATE ANY DATABASE;
GO
:CONNECT $(NODE01)
RAISERROR('Connecting back to primary $(NODE01)...',0,1) WITH NOWAIT;
GO