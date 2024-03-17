/*** WARNING! This script is only for new AG installation only!! ***/
/*** DO NOT use the script on an already running AG environment! ***/

/***************** PLEASE ENABLE SQLCMD MODE!! ******************/
-- make sure to change the variables values accordingly
-- please wait until all replicas are synchronized
-- you can check the seeding process with this dmv
-- SELECT * FROM sys.dm_hadr_physical_seeding_stats;
-- SELECT * FROM sys.dm_hadr_automatic_seeding;
/****************************************************************/
/* Declare variables */
-- the AG name
:SETVAR AGNAME "AOAG01"
-- the listener name and IP address(es)
:SETVAR ISMULTISUBNET "1"
:SETVAR LISTNR "AOAG01LISTNR"
:SETVAR LISTNRIP1 "10.0.0.11"
:SETVAR LISTNRIP1NETMASK "255.255.255.0"
:SETVAR LISTNRIP2 "172.16.0.11"
:SETVAR LISTNRIP2NETMASK "255.240.0.0"
:SETVAR LISTNRPORT "1433"

PRINT 'Set SQLCMD variables done!';
GO

SELECT '$(AGNAME)' AS ag_name, '$(LISTNR)' AS listnr_name, '$(LISTNRIP1)' AS listnr_ip1, '$(LISTNRIP1NETMASK)' AS listnr_ip1_mask, 
	   '$(LISTNRIP2)' AS listnr_ip2, '$(LISTNRIP2NETMASK)' AS listnr_ip2_mask;

GO
/* Here we create a listener for our AG. If you have issues creating the listener check permissions in AD. */
RAISERROR('Creating availability group listener...',0,1) WITH NOWAIT;
GO
IF 1 = $(ISMULTISUBNET)
ALTER AVAILABILITY GROUP [$(AGNAME)]
ADD LISTENER N'$(LISTNR)' (
WITH IP ((N'$(LISTNRIP1)', N'$(LISTNRIP1NETMASK)'),(N'$(LISTNRIP2)', N'$(LISTNRIP2NETMASK)')), PORT=$(LISTNRPORT));
ELSE
ALTER AVAILABILITY GROUP [$(AGNAME)]
ADD LISTENER N'$(LISTNR)' (
WITH IP ((N'$(LISTNRIP1)', N'$(LISTNRIP1NETMASK)')), PORT=$(LISTNRPORT));
GO
RAISERROR('Availability group listener is created...',0,1) WITH NOWAIT;
GO