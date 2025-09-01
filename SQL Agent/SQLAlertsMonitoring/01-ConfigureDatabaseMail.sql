USE master;
GO
EXEC sp_configure 'Show Advanced', '1';
RECONFIGURE
GO
sp_configure 'Database Mail XPs',1
RECONFIGURE
GO
USE msdb;
GO
-- Add mail profile
EXECUTE msdb.dbo.sysmail_add_profile_sp
    @profile_name = 'SQLAlertMail',
    @description = 'Database Mail for sending SQL alert and notification.';
    
-- Create database mail account
EXECUTE msdb.dbo.sysmail_add_account_sp
    @account_name = 'SQLAlert',
    @description = 'SQLAlert',
    @email_address = 'db.admin@email.com',
    @display_name = 'SQLAlert',
    @replyto_address = NULL,
    @mailserver_name = 'relay.smtp.email.com',
	@mailserver_type = SMTP,  
	@port = 25,
	@username  = NULL,
	@password  = NULL,
	@use_default_credentials = 0,
	@enable_ssl  = 0;
    
-- Add the account to the profile
EXECUTE msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = 'SQLAlertMail',
    @account_name = 'SQLAlert',
    @sequence_number = 1 ;

-- Set the New Profile public 
EXECUTE msdb.dbo.sysmail_add_principalprofile_sp 
	@profile_name = 'SQLAlertMail',
    @principal_name = 'public', 
    @is_default = 0 ;
GO 
SELECT * FROM msdb.dbo.sysmail_profile 
SELECT * FROM msdb.dbo.sysmail_account 
SELECT * FROM msdb.dbo.sysmail_server
GO
/* Test email profile sending email */
EXEC msdb.dbo.sp_send_dbmail  @profile_name = 'SQLAlertMail', 
                              @subject = 'Database Mail Test',
                              @recipients = 'db.admin@email.com',
                              @body = 'This is a test e-mail sent from Database Mail on SQL Server.'
GO
