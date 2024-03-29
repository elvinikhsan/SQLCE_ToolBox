USE tempdb;
GO
CREATE OR ALTER PROCEDURE [dbo].[usp_rename_objects_and_reseed_identity]
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRANSACTION
		-- Rename original tables as <name>Old
		EXEC sp_rename 'dbo.SourceTest', 'SourceTest_Old';
		-- Rename the primary key <PK_name>Old
		EXEC sp_rename N'dbo.SourceTest_Old.PK_SourceTest', N'PK_SourceTest_Old', N'INDEX';
		-- Rename the constraint as old 
		EXEC sp_rename N'dbo.DF_SourceTest_CreatedDate', N'DF_SourceTest_Old_CreatedDate', N'OBJECT';
		-- Rename the new table as original table
		EXEC sp_rename 'dbo.SourceTest_Temp', 'SourceTest';
		-- Rename the primary key as original PK
		EXEC sp_rename N'dbo.SourceTest.PK_SourceTest_Temp', N'PK_SourceTest', N'INDEX';
		-- Rename the constraint as original 
		EXEC sp_rename N'dbo.DF_SourceTest_Temp_CreatedDate', N'DF_SourceTest_CreatedDate', N'OBJECT';
		-- Reseed identity if the target table has identity column
		DBCC CHECKIDENT('dbo.SourceTest', RESEED);
		-- Commit transaction
		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; 
		THROW;
	END CATCH
END