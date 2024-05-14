select
    ag.name,
    ar.replica_server_name,
    ar.availability_mode_desc as [availability_mode],
    ars.synchronization_health_desc as replica_sync_state,
    rcs.database_name,
    drs.synchronization_state_desc as db_sync_state,
    rcs.is_failover_ready,
    rcs.is_pending_secondary_suspend,
    rcs.is_database_joined
from sys.dm_hadr_database_replica_cluster_states as rcs
join sys.availability_replicas as ar
    on ar.replica_id = rcs.replica_id
join sys.dm_hadr_availability_replica_states as ars
    on ars.replica_id = ar.replica_id
join sys.dm_hadr_database_replica_states as drs
    on drs.group_database_id = rcs.group_database_id
    and drs.replica_id = ar.replica_id
join sys.availability_groups as ag
    on ag.group_id = ar.group_id