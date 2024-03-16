/*** WARNING! This script is only for new AG installation only!! ***/
/*** DO NOT use the script on an already running AG environment! ***/

/***************** PLEASE ENABLE SQLCMD MODE!! ******************/
-- make sure to change the variables values accordingly
/****************************************************************/
/* Declare variables */
-- the domain name
:SETVAR DNS ".contoso.com"
-- the nodes name
:SETVAR NODE01 "NODE01"
:SETVAR NODE02 "NODE02"
:SETVAR NODE03 "NODE03"
-- the AG name
:SETVAR AGNAME "AOAG01"

PRINT 'Set SQLCMD variables done!';
GO
-- connect to primary
:CONNECT $(NODE01)
USE [master]
GO
ALTER AVAILABILITY GROUP [$(AGNAME)]
MODIFY REPLICA ON N'$(NODE01)' WITH (SECONDARY_ROLE(READ_ONLY_ROUTING_URL = N'TCP://$(NODE01)$(DNS):1433'));
GO
ALTER AVAILABILITY GROUP [$(AGNAME)]
MODIFY REPLICA ON N'$(NODE02)' WITH (SECONDARY_ROLE(READ_ONLY_ROUTING_URL = N'TCP://$(NODE02)$(DNS):1433'));
GO
ALTER AVAILABILITY GROUP [$(AGNAME)]
MODIFY REPLICA ON N'$(NODE03)' WITH (SECONDARY_ROLE(READ_ONLY_ROUTING_URL = N'TCP://$(NODE03)$(DNS):1433'));
GO
ALTER AVAILABILITY GROUP [$(AGNAME)]
MODIFY REPLICA ON N'$(NODE01)' WITH (PRIMARY_ROLE(READ_ONLY_ROUTING_LIST = ((N'$(NODE02)',N'$(NODE03)'),N'$(NODE01)')));
GO
ALTER AVAILABILITY GROUP [$(AGNAME)]
MODIFY REPLICA ON N'$(NODE02)' WITH (PRIMARY_ROLE(READ_ONLY_ROUTING_LIST = ((N'$(NODE01)',N'$(NODE03)'),N'$(NODE02)')));
GO
ALTER AVAILABILITY GROUP [$(AGNAME)]
MODIFY REPLICA ON N'$(NODE03)' WITH (PRIMARY_ROLE(READ_ONLY_ROUTING_LIST = ((N'$(NODE01)',N'$(NODE02)'),N'$(NODE03)')));
GO
