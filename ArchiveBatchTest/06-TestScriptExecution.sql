USE tempdb;
GO
/*** Please note: This is just a test script in order to show an example of data archiving process ***/
/*** By using batch process per transaction for moving data on a monthly basis to an archive table ***/
/*** These SPs provided are for reference only, adjust the logic to match your specific requirements ***/
/*** In general, sliding window partitioning is the preferred method of moving very large data.  ***/

/* Step 01 - Move initial data to a temp table 
-- This will be last 3 months data we want to keep as per this demo requirement
-- Make sure the date parameter values are correct and using 'YYYYMMDD' format
-- Example: Data for Jan-March 2023 with 100.000 batch size per transaction */

EXEC [dbo].[usp_move_initial_data] '20230101', '20230331', 100000;

GO

/* Step 02 - Switch the names of the tables and reseed identity 
-- The SourceTest table will be renamed to SourceTest_Old
-- The SourceTest_Temp table will be renamed to SourceTest */

EXEC [dbo].[usp_rename_objects_and_reseed_identity];

GO

/* Step 03 - Create SQL Agent job to schedule monthly archive prosess
-- Make sure the job contains logic to get the correct date, which is the first day of the oldest month 
-- Whose data we want to move to an archive table by executing a stored procedure below passing the date  
-- For example, assume that January 2023 is the oldest data we want to archive */

EXEC [dbo].[usp_archive_monthly_data] '20230101', 100000;

GO
