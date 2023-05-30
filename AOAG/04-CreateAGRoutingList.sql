/*** WARNING! This script is only for new AG installation only!! ***/
/*** DO NOT use the script on an already running AG environment! ***/

/***************** PLEASE ENABLE SQLCMD MODE!! ******************/
-- make sure to change the variables values accordingly
/****************************************************************/
/* Declare variables */
-- the domain name
:SETVAR DNS ".contoso.com"
-- the nodes name
:SETVAR NODE1 "NODE1"
:SETVAR NODE2 "NODE2"
:SETVAR NODE3 "NODE3"
-- the AG name
:SETVAR AGNAME "AOAG1"

PRINT 'Set SQLCMD variables done!';
GO
-- connect to primary
:CONNECT $(NODE1)
USE [master]
GO
ALTER AVAILABILITY GROUP [$(AGNAME)]
MODIFY REPLICA ON N'$(NODE1)' WITH (SECONDARY_ROLE(READ_ONLY_ROUTING_URL = N'TCP://$(NODE1)$(DNS):1433'));
GO
ALTER AVAILABILITY GROUP [$(AGNAME)]
MODIFY REPLICA ON N'$(NODE2)' WITH (SECONDARY_ROLE(READ_ONLY_ROUTING_URL = N'TCP://$(NODE2)$(DNS):1433'));
GO
ALTER AVAILABILITY GROUP [$(AGNAME)]
MODIFY REPLICA ON N'$(NODE3)' WITH (SECONDARY_ROLE(READ_ONLY_ROUTING_URL = N'TCP://$(NODE3)$(DNS):1433'));
GO
ALTER AVAILABILITY GROUP [$(AGNAME)]
MODIFY REPLICA ON N'$(NODE1)' WITH (PRIMARY_ROLE(READ_ONLY_ROUTING_LIST = ((N'$(NODE2)',N'$(NODE3)'),N'$(NODE1)')));
GO
ALTER AVAILABILITY GROUP [$(AGNAME)]
MODIFY REPLICA ON N'$(NODE2)' WITH (PRIMARY_ROLE(READ_ONLY_ROUTING_LIST = ((N'$(NODE1)',N'$(NODE3)'),N'$(NODE2)')));
GO
ALTER AVAILABILITY GROUP [$(AGNAME)]
MODIFY REPLICA ON N'$(NODE3)' WITH (PRIMARY_ROLE(READ_ONLY_ROUTING_LIST = ((N'$(NODE1)',N'$(NODE2)'),N'$(NODE3)')));
GO
