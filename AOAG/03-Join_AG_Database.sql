/*** WARNING! This script is intended for PoC Environment! ***/
/*** DO NOT run the script in Production environment without testing! ***/

/***************** PLEASE ENABLE SQLCMD MODE!! ******************/
-- Change the variables values accordingly to match the environment
-- This script is using manual database initialization backup/restore
-- Make sure you have performed the FULL/LOG backup of the database 
-- And restore the database to all secondary replicas WITH NORECOVERY
/****************************************************************/

/* Declare variables */
-- The AG name
:SETVAR AGNAME "AOAG01"
-- The secondary replicas name
:SETVAR NODE01 "NODE01"
:SETVAR NODE02 "NODE02"
:SETVAR NODE03 "NODE03"
-- The database name
:SETVAR DBNAME "DUMMYDB"

PRINT 'Set SQLCMD variables done!';
GO
:CONNECT $(NODE02)
RAISERROR('Connecting to $(NODE02)...',0,1) WITH NOWAIT;
GO
USE master;
GO
-- Wait for the replica to start communicating
BEGIN TRY
    DECLARE @conn BIT
    DECLARE @count INT
    DECLARE @replica_id UNIQUEIDENTIFIER
    DECLARE @group_id UNIQUEIDENTIFIER

    SET @conn = 0
    SET @count = 30 -- wait for 5 minutes 
    IF (SERVERPROPERTY('IsHadrEnabled') = 1)
       AND (ISNULL((SELECT member_state FROM master.sys.dm_hadr_cluster_members
					WHERE UPPER(member_name) = UPPER(CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(256)))),0) <> 0)
       AND (ISNULL((SELECT state FROM master.sys.database_mirroring_endpoints),1) = 0)
    BEGIN
        SELECT @group_id = ags.group_id
        FROM master.sys.availability_groups AS ags
        WHERE NAME = N'$(AGNAME)'

        SELECT @replica_id = replicas.replica_id
        FROM master.sys.availability_replicas AS replicas
        WHERE UPPER(replicas.replica_server_name) = UPPER(@@SERVERNAME)
              AND group_id = @group_id

        WHILE @conn <> 1 AND @count > 0
        BEGIN
            SET @conn = ISNULL((SELECT connected_state FROM master.sys.dm_hadr_availability_replica_states AS states WHERE states.replica_id = @replica_id),1)

            IF @conn = 1
            BEGIN
                -- exit loop when the replica is connected, or if the query cannot find the replica status
                BREAK
            END

            WAITFOR DELAY '00:00:10'

            SET @count = @count - 1
        END
    END
END TRY
BEGIN CATCH
-- If the wait loop fails, do not stop execution of the alter database statement
END CATCH

RAISERROR('Joining database $(DBNAME) in $(NODE02) to $(AGNAME)...',0,1) WITH NOWAIT;

ALTER DATABASE [$(DBNAME)] SET HADR AVAILABILITY GROUP = [$(AGNAME)];

RAISERROR('Joining database $(DBNAME) is completed...',0,1) WITH NOWAIT;
GO
:CONNECT $(NODE03)
RAISERROR('Connecting to $(NODE03)...',0,1) WITH NOWAIT;
GO
USE master;
GO
-- Wait for the replica to start communicating
BEGIN TRY
    DECLARE @conn BIT
    DECLARE @count INT
    DECLARE @replica_id UNIQUEIDENTIFIER
    DECLARE @group_id UNIQUEIDENTIFIER

    SET @conn = 0
    SET @count = 30 -- wait for 5 minutes 
    IF (SERVERPROPERTY('IsHadrEnabled') = 1)
       AND (ISNULL((SELECT member_state FROM master.sys.dm_hadr_cluster_members
					WHERE UPPER(member_name) = UPPER(CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(256)))),0) <> 0)
       AND (ISNULL((SELECT state FROM master.sys.database_mirroring_endpoints),1) = 0)
    BEGIN
        SELECT @group_id = ags.group_id
        FROM master.sys.availability_groups AS ags
        WHERE NAME = N'$(AGNAME)'

        SELECT @replica_id = replicas.replica_id
        FROM master.sys.availability_replicas AS replicas
        WHERE UPPER(replicas.replica_server_name) = UPPER(@@SERVERNAME)
              AND group_id = @group_id

        WHILE @conn <> 1 AND @count > 0
        BEGIN
            SET @conn = ISNULL((SELECT connected_state FROM master.sys.dm_hadr_availability_replica_states AS states WHERE states.replica_id = @replica_id),1)

            IF @conn = 1
            BEGIN
                -- exit loop when the replica is connected, or if the query cannot find the replica status
                BREAK
            END

            WAITFOR DELAY '00:00:10'

            SET @count = @count - 1
        END
    END
END TRY
BEGIN CATCH
-- If the wait loop fails, do not stop execution of the alter database statement
END CATCH

RAISERROR('Joining database $(DBNAME) in $(NODE03) to $(AGNAME)...',0,1) WITH NOWAIT;

ALTER DATABASE [$(DBNAME)] SET HADR AVAILABILITY GROUP = [$(AGNAME)];

RAISERROR('Joining database $(DBNAME) is completed...',0,1) WITH NOWAIT;
GO
:CONNECT $(NODE01)
RAISERROR('Connecting back to primary $(NODE01)...',0,1) WITH NOWAIT;
GO