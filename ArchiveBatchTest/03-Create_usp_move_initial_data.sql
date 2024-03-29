USE tempdb;
GO
CREATE OR ALTER PROCEDURE [dbo].[usp_move_initial_data]
(@startDate DATETIME = NULL -- date string format 'YYYYMMDD'
,@endDate DATETIME = NULL -- date string format 'YYYYMMDD'
,@batchSize BIGINT = NULL)
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @rows BIGINT;
	DECLARE @currentEOM DATETIME;

	-- Check parameters, if any is NULL, abort operation
	IF @startDate IS NULL OR @endDate IS NULL OR @batchSize IS NULL
		OR (@endDate < @startDate)
	BEGIN
		;THROW 50000, 'Invalid parameters!',16; 
	END

	-- Initialize variables
	SET @rows = 1;
	IF EOMONTH(@startDate) = EOMONTH(@endDate)
	BEGIN
		-- End date is on the same month, simple move all data until end date
		SET @currentEOM = @endDate;
	END
	ELSE
	BEGIN
		-- End date is not the same month, so let's start moving data of current month
		SET @currentEOM = EOMONTH(@startDate);
	END
	
	-- Check if data exists
	IF NOT EXISTS (SELECT 1 FROM dbo.SourceTest WHERE CreatedDate >= @startDate AND CreatedDate < @currentEOM + 1)
	BEGIN
		;THROW 50000, 'There is no data within date range!',16;
	END

	BEGIN TRY
		WHILE @currentEOM <= @endDate
		BEGIN
			-- if target table has identity column make sure insert identity ON
			SET IDENTITY_INSERT dbo.SourceTest_Temp ON;

			WHILE @rows <> 0
			BEGIN
				BEGIN TRANSACTION;

				DELETE TOP(@batchSize) FROM dbo.sourceTest 
				OUTPUT deleted.Id, deleted.Content, deleted.CreatedDate 
				INTO dbo.SourceTest_Temp (Id, Content, CreatedDate)
				WHERE CreatedDate >= @startDate AND CreatedDate < @currentEOM + 1;

				SET @rows = ROWCOUNT_BIG();
				COMMIT TRANSACTION;
			END
			SET @rows = 1;
			SET @currentEOM = @currentEOM + 1;
			IF @currentEOM <= @endDate 
			BEGIN
				SET @currentEOM = EOMONTH(@currentEOM);
				IF @currentEOM >= @endDate SET @currentEOM = @endDate;
			END
		END
		-- if target table has identity column make sure insert identity OFF
		SET IDENTITY_INSERT dbo.SourceTest_Temp OFF;
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; 
		-- if target table has identity column make sure insert identity OFF
		SET IDENTITY_INSERT dbo.SourceTest_Temp OFF;
		THROW;
	END CATCH
END

