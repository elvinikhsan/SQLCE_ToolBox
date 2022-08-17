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
-- the AG name
:SETVAR AGNAME "AOAG1"
-- the database name
:SETVAR DBNAME "DUMMYDB"

PRINT 'Set SQLCMD variables done!';
GO

SELECT '$(DNS)' AS dns_name, '$(SQLSERVICE)' AS sqlservice_account, '$(AGNAME)' AS ag_name, '$(DBNAME)' AS dbs_name,
	   '$(NODE1)' AS node1, '$(NODE1)$(DNS)' AS node1_fqdn, '$(NODE1IP)' AS node1_ip, 
	   '$(NODE2)' AS node2, '$(NODE2)$(DNS)' AS node2_fqdn, '$(NODE2IP)' AS node2_ip, 
	   '$(NODE3)' AS node3, '$(NODE3)$(DNS)' AS node3_fqdn, '$(NODE3IP)' AS node3_ip;
GO
/* Create availability group */
-- With SQL 2016+ we can use Direct Seeding instead for small-medium database size.
-- Here we connect to our primary replica (NODE1) and create our AG. */
:Connect $(NODE1)
/* We can use trace flag 9567 to enable compression for the VDI backup for the seeding process */
RAISERROR('Turning on TRACE 9567 on NODE1...',0,1) WITH NOWAIT;
GO
DBCC TRACEON (9567, -1);
GO
:CONNECT $(NODE1)
GO
USE [master]
GO
RAISERROR('Creating always on availability group...',0,1) WITH NOWAIT;
GO
CREATE AVAILABILITY GROUP [$(AGNAME)]
WITH (AUTOMATED_BACKUP_PREFERENCE = SECONDARY,DB_FAILOVER = ON, DTC_SUPPORT = PER_DB, FAILURE_CONDITION_LEVEL = 3, HEALTH_CHECK_TIMEOUT = 60000, CLUSTER_TYPE = WSFC)
FOR DATABASE [$(DBNAME)]
REPLICA ON N'$(NODE1)' WITH (ENDPOINT_URL = N'TCP://$(NODE1)$(DNS):5022', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, SESSION_TIMEOUT = 10, BACKUP_PRIORITY = 50, SEEDING_MODE = AUTOMATIC, PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL), SECONDARY_ROLE(ALLOW_CONNECTIONS = ALL)),
	N'$(NODE2)' WITH (ENDPOINT_URL = N'TCP://$(NODE2)$(DNS):5022', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, SESSION_TIMEOUT = 10, BACKUP_PRIORITY = 60, SEEDING_MODE = AUTOMATIC, PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL), SECONDARY_ROLE(ALLOW_CONNECTIONS = ALL)),
	N'$(NODE3)' WITH (ENDPOINT_URL = N'TCP://$(NODE3)$(DNS):5022', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, SESSION_TIMEOUT = 10, BACKUP_PRIORITY = 40, SEEDING_MODE = AUTOMATIC, PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL), SECONDARY_ROLE(ALLOW_CONNECTIONS = ALL));
GO
RAISERROR('Always on avaibility group created...',0,1) WITH NOWAIT;
GO
:CONNECT $(NODE2)
RAISERROR('Joining NODE1...',0,1) WITH NOWAIT;
GO
ALTER AVAILABILITY GROUP [$(AGNAME)] JOIN;
GO
ALTER AVAILABILITY GROUP [$(AGNAME)] GRANT CREATE ANY DATABASE;
GO
:CONNECT $(NODE3)
RAISERROR('Joining NODE3...',0,1) WITH NOWAIT;
GO
ALTER AVAILABILITY GROUP [$(AGNAME)] JOIN;
GO
ALTER AVAILABILITY GROUP [$(AGNAME)] GRANT CREATE ANY DATABASE;
GO