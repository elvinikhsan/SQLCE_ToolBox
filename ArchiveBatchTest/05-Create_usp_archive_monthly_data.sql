USE tempdb;
GO
CREATE OR ALTER PROCEDURE [dbo].[usp_archive_monthly_data]
(@startDate DATETIME = NULL -- date string format 'YYYYMMDD'
,@batchSize BIGINT = NULL)
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @rows BIGINT;
	DECLARE @currentEOM DATETIME;

	-- Check parameters, if any is NULL, abort operation
	IF @startDate IS NULL OR @batchSize IS NULL
	BEGIN
		;THROW 50000, 'Invalid parameters!',16; 
	END

	-- Initialize variables
	SET @rows = 1;
	SET @currentEOM = EOMONTH(@startDate);
	
	-- Check if data exists
	IF NOT EXISTS (SELECT 1 FROM dbo.SourceTest WHERE CreatedDate >= @startDate AND CreatedDate < @currentEOM + 1)
	BEGIN
		;THROW 50000, 'There is no data within date range!',16;
	END

	BEGIN TRY
		WHILE @rows <> 0
		BEGIN
			BEGIN TRANSACTION;

			DELETE TOP(@batchSize) FROM dbo.sourceTest 
			OUTPUT deleted.Id, deleted.Content, deleted.CreatedDate 
			INTO dbo.ArchiveTest (Id, Content, CreatedDate)
			WHERE CreatedDate >= @startDate AND CreatedDate < @currentEOM + 1;

			SET @rows = ROWCOUNT_BIG();
			COMMIT TRANSACTION;
		END
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; 
		THROW;
	END CATCH
END

