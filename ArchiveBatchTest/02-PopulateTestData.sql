USE tempdb;
GO
-- Populate test data 
-- To populate data for multiple months, 
-- Just change the start date to new first day of the month 
-- And rerun the script for each month of data
SET NOCOUNT ON;
DECLARE @startDate DATETIME = '20230101';
DECLARE @endDate DATETIME;
DECLARE @currentDate DATETIME;
DECLARE @i INT = 1;
DECLARE @maxrows INT = 10000;

SET @currentDate = @startDate;
SET @endDate = EOMONTH(@startDate);

WHILE @currentDate <= @endDate
BEGIN
	BEGIN TRAN;
	WHILE @i <= @maxrows
	BEGIN
		INSERT INTO dbo.SourceTest (Content, CreatedDate) VALUES ('A',@currentDate );
		SET @i = @i + 1;
	END
	COMMIT TRAN;
	SET @i = 1;
	SET @currentDate = @currentDate + 1;
END
GO
