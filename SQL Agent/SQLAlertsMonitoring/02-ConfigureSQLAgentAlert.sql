/* Create Operator */
USE [msdb]
GO
EXEC msdb.dbo.sp_add_operator @name=N'DB.Admin', 
		@enabled=1, 
		@weekday_pager_start_time=90000, 
		@weekday_pager_end_time=180000, 
		@saturday_pager_start_time=90000, 
		@saturday_pager_end_time=180000, 
		@sunday_pager_start_time=90000, 
		@sunday_pager_end_time=180000, 
		@pager_days=0, 
		@email_address=N'db.admin@email.com', 
		@category_name=N'[Uncategorized]'
GO
-- Update SQL Agent Settings Alert System 
USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1, 
		@databasemail_profile=N'SQLAlertMail', 
		@use_databasemail=1
GO
EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator=N'DB.Admin', @notificationmethod=1
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1, 
		@alert_replace_runtime_tokens=1
GO