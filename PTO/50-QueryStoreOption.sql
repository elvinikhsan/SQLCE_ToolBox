SELECT actual_state_desc, desired_state_desc, [interval_length_minutes],
       current_storage_size_mb, [max_storage_size_mb], 
	   query_capture_mode_desc, size_based_cleanup_mode_desc
FROM sys.database_query_store_options WITH (NOLOCK) OPTION (RECOMPILE);