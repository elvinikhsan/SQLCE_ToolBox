/*attention event: 
Indicates that a cancel operation, client-interrupt request, or broken client connection has occurred. 
Be aware that cancel operations can also occur as the result of implementing data access driver time-outs, aborted.*/
CREATE EVENT SESSION [ApplicationTimeout] ON SERVER 
ADD EVENT sqlserver.attention(
    ACTION(package0.event_sequence,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.username)
    WHERE ([package0].[equal_boolean]([sqlserver].[is_system],(0)) AND [package0].[greater_than_uint64]([sqlserver].[database_id],(5)) AND [sqlserver].[session_id]>(50)))
ADD TARGET package0.event_file(SET filename=N'AppQueryTimeout',max_file_size=(100),max_rollover_files=(5))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO


