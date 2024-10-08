USE master;
GO
CREATE OR ALTER PROCEDURE dbo.sp_ShrinkFilesDecremental
(@DatabaseName SYSNAME
,@FileType VARCHAR(4) = 'DATA'
,@ShrinkSizeMB INT = 1024
,@MaxRetries INT = 10
,@TruncateOnly BIT = 0)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	
	DECLARE @sqlstrfilesize NVARCHAR(MAX) = N'';
	DECLARE @sqlstr NVARCHAR(MAX) = N'';
	DECLARE @trycount INT = 0;

	DECLARE @sqlcommand AS TABLE (ID INT IDENTITY(1,1), CommandText NVARCHAR(MAX));

	CREATE TABLE #FileSize 
	(FileID INT NOT NULL
	,[FileName] SYSNAME NOT NULL
	,[SizeMB] DECIMAL(17,2) NULL
	,[UsedMB] DECIMAL(17,2) NULL
	,[FreeMB] DECIMAL(17,2) NULL);

	CREATE TABLE #FileList
	(SeqID INT NOT NULL
	,FileID INT NOT NULL
	,[FileName] SYSNAME NOT NULL
	,[FileState] NVARCHAR(60) NOT NULL
	,[SizeMB] DECIMAL(17,2) NULL
	,[UsedMB] DECIMAL(17,2) NULL
	,[FreeMB] DECIMAL(17,2) NULL);
	
	IF UPPER(@FileType) <> 'DATA'
	BEGIN
		RAISERROR('Currently only data file is supported.',16,1);
		RETURN;
	END

	IF (SELECT CASE WHEN has_dbaccess(@DatabaseName) = 1 THEN 'true' ELSE 'false' END) = 'false'
	BEGIN
		RAISERROR('User do not have access to the database.',16,1);
		RETURN;
	END

	SET @sqlstrfilesize = N'USE ' + QUOTENAME(@DatabaseName) + ';
                BEGIN TRY
                DECLARE @filestats_temp_table table(
                file_id int
                ,       file_group_id int
                ,       total_extents BIGINT
                ,       used_extents BIGINT
                ,       logical_file_name nvarchar(500) collate database_default
                ,       physical_file_name nvarchar(500) collate database_default
                );

                INSERT INTO @filestats_temp_table
                EXEC (''DBCC SHOWFILESTATS WITH NO_INFOMSGS'');

				WITH CTE AS (
                SELECT file_id AS FileID, logical_file_name AS FileName
                ,CAST ((total_extents * 64) / 1024.0 AS DECIMAL(17,2)) AS SizeMB
                ,CAST ((used_extents * 64) / 1024.0 AS DECIMAL(17,2)) AS UsedMB
                FROM @filestats_temp_table)
				INSERT INTO #FileSize (FileID, [FileName], SizeMB, UsedMB, FreeMB) 
				SELECT FileID, FileName, SizeMB, UsedMB, (SizeMB - UsedMB) AS FreeMB
				FROM CTE;

                END TRY
                BEGIN CATCH
                SELECT -100 as l1
                ,ERROR_NUMBER() as file_group_name
                ,ERROR_SEVERITY() as logical_file_name
                ,ERROR_STATE() as physical_file_name
                ,ERROR_MESSAGE() as space_reserved
                ,1 as space_reserved_unit, 1 as space_used, 1 as space_used_unit
                END CATCH;'
 
	EXEC sp_executesql @sqlstrfilesize;

	INSERT INTO #FileList (SeqID, FileID, FileName, FileState, SizeMB, UsedMB, FreeMB)
	SELECT ROW_NUMBER() OVER (ORDER BY a.FreeMB DESC) AS SeqID, a.FileID, a.FileName, b.state_desc, a.SizeMB, a.UsedMB, a.FreeMB
	FROM #FileSize a
	INNER JOIN sys.master_files b
	ON a.FileID = b.file_id
	WHERE DB_NAME(b.database_id) = @DatabaseName 
	AND b.state_desc = N'ONLINE';

	IF NOT EXISTS (SELECT 1 FROM #FileList) OR EXISTS (SELECT 1 FROM #FileList WHERE FileState <> N'ONLINE')
	BEGIN
		RAISERROR('Database is not available or not all files in online state.', 16,1);
		RETURN;
	END

	DECLARE @fileName NVARCHAR(MAX); 
	DECLARE @count INT = 0;
	DECLARE @j INT =1;

	SELECT @count=COUNT(*) FROM #FileList;

	-- generate shrink commands and store it in @sqlcommand
	WHILE @j <= @count
	BEGIN  
		   SET @sqlstr = N'';
		   SELECT @filename = [FileName] FROM #FileList WHERE SeqID=@j;
		   
		   IF @TruncateOnly = 0
		   SET @sqlstr = N'USE ' + QUOTENAME(@DatabaseName) + N'; DBCC SHRINKFILE (N' + QUOTENAME(@fileName,'''') + ',' + CAST(@ShrinkSizeMB AS NVARCHAR) + N') WITH NO_INFOMSGS;';
		   ELSE
		   SET @sqlstr = N'USE ' + QUOTENAME(@DatabaseName) + N'; DBCC SHRINKFILE (N' + QUOTENAME(@fileName,'''') + ',' + CAST(@ShrinkSizeMB AS NVARCHAR) + N',TRUNCATEONLY) WITH NO_INFOMSGS;';


		   INSERT INTO @sqlcommand(CommandText) VALUES (@sqlstr);
		   SET @j=@j+1;
	END  

	--execute the shrink commands
	SET @j=1;
	WHILE @j<= @count
	BEGIN
		DECLARE @PrevFreeMB INT;
		DECLARE @FreeMB INT;
		DECLARE @DecrementMB INT;
		DECLARE @PrevDecrementMB INT;
		DECLARE @InfoMessages NVARCHAR(255);

		SELECT	@fileName = [FileName], 
				@FreeMB = CAST(FreeMB AS INT), 
				@DecrementMB = CASE WHEN CAST(FreeMB AS INT) <= @ShrinkSizeMB THEN CAST(FreeMB AS INT)
									 WHEN CAST(FreeMB AS INT) > @ShrinkSizeMB THEN CAST(FreeMB AS INT) - @ShrinkSizeMB
								END		
		FROM #FileList 
		WHERE SeqID = @j;

		SET @PrevDecrementMB = @ShrinkSizeMB;
		SET @InfoMessages = N'Shrinking file ' + @fileName + '...';
		RAISERROR(@InfoMessages, 0, 1) WITH NOWAIT;

		WHILE @FreeMB > @ShrinkSizeMB
		BEGIN
			DECLARE @sqlcmd NVARCHAR(MAX)=N'';

			IF @TruncateOnly = 0
			UPDATE @sqlcommand SET @sqlcmd = CommandText = REPLACE(CommandText, ',' + CAST(@PrevDecrementMB AS NVARCHAR) + ')', ',' + CAST(@DecrementMB AS NVARCHAR) + ')')
			FROM @sqlcommand WHERE ID=@j;
			ELSE
			UPDATE @sqlcommand SET @sqlcmd = CommandText = REPLACE(CommandText, ',' + CAST(@PrevDecrementMB AS NVARCHAR) + ',', ',' + CAST(@DecrementMB AS NVARCHAR) + ',')
			FROM @sqlcommand WHERE ID=@j;

			SET @InfoMessages = N'Executing ' + @sqlcmd + '...';
			RAISERROR(@InfoMessages,0,1) WITH NOWAIT;

			EXEC (@sqlcmd);

			TRUNCATE TABLE #FileSize;
			EXEC sp_executesql @sqlstrfilesize;

			SET @InfoMessages = (SELECT CONCAT_WS(' | ',FileId, FileName, SizeMB, FreeMB) FROM #FileSize WHERE FileName = @fileName);
			RAISERROR(@InfoMessages,0,1) WITH NOWAIT;

			SET @PrevDecrementMB = @DecrementMB;
			SET @PrevFreeMB = @FreeMB;

			SELECT @FreeMB = CAST(FreeMB AS INT), 
				@DecrementMB = CASE WHEN CAST(FreeMB AS INT) <= @ShrinkSizeMB THEN CAST(FreeMB AS INT)
									 WHEN CAST(FreeMB AS INT) > @ShrinkSizeMB THEN CAST(FreeMB AS INT) - @ShrinkSizeMB
								END
			FROM #FileSize WHERE FileName = @fileName;

			IF (@PrevFreeMB = @FreeMB) OR ((@PrevFreeMB - @FreeMB)/@ShrinkSizeMB*100 < 5) -- less than 5%
			BEGIN
				IF @trycount = @MaxRetries
				BEGIN
					SET @InfoMessages = N'The process has reached max number of retries threshold which result in less than 5% freed size. Further operation on this file is aborted.'
					RAISERROR(@InfoMessages,0,1) WITH NOWAIT;
					BREAK;
				END 

				SET @trycount = @trycount + 1;
			END

			
			IF @FreeMB < @ShrinkSizeMB
			BEGIN
				SET @InfoMessages = N'Current free size of ' + CAST(@FreeMB AS NVARCHAR) + 'MB is below target shrink size of ' + CAST(@ShrinkSizeMB AS NVARCHAR) + 'MB, shrink process for this file is completed.';
				RAISERROR(@InfoMessages,0,1) WITH NOWAIT;
				BREAK;
			END

			SET @InfoMessages = N'Current free size of ' + CAST(@FreeMB AS NVARCHAR) + 'MB is still above target shrink size of ' + CAST(@ShrinkSizeMB AS NVARCHAR) + 'MB, continuing the file shrink process...';
			RAISERROR(@InfoMessages,0,1) WITH NOWAIT;
			
			WAITFOR DELAY '00:00:05';
		END
		
		SET @j=@j+1;
	END
END