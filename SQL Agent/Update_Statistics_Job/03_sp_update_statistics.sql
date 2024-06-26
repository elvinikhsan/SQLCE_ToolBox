USE [master]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_update_statistics]
(	@Databases nvarchar(max) = NULL,
	@MaxDOP int = NULL,
	@UpdateStatistics nvarchar(max) = NULL,
	@OnlyModifiedStatistics nvarchar(max) = 'N',
	@StatisticsModificationLevel int = NULL,
	@StatisticsSample int = NULL,
	@StatisticsResample nvarchar(max) = 'N',
	@PartitionLevel nvarchar(max) = 'Y',
	@Indexes nvarchar(max) = NULL,
	@TimeLimit int = NULL,
	@Delay int = NULL,
	@LockTimeout int = NULL,
	@LockMessageSeverity int = 16,
	@StringDelimiter nvarchar(max) = ',',
	@LogToTable nvarchar(max) = 'Y')
AS
BEGIN
	SET NOCOUNT ON;
	SET ARITHABORT ON;
	SET NUMERIC_ROUNDABORT OFF;

	CREATE TABLE #Errors 
	(	ID int IDENTITY PRIMARY KEY,
		[Message] nvarchar(max) NOT NULL,
		Severity int NOT NULL,
		[State] int);

	CREATE TABLE #tmpDatabases 
	(	ID int IDENTITY,
		DatabaseName nvarchar(max),
		DatabaseType nvarchar(max),
		StartPosition int,
		DatabaseSize bigint,
		[Order] int,
		Selected bit,
		Completed bit,
		PRIMARY KEY(Selected, Completed, [Order], ID));

	CREATE TABLE #SelectedDatabases 
	(	DatabaseName nvarchar(max),
		DatabaseType nvarchar(max),
		StartPosition int,
		Selected bit);

	CREATE TABLE #SelectedIndexes  
	(	DatabaseName nvarchar(max),
		SchemaName nvarchar(max),
		ObjectName nvarchar(max),
		IndexName nvarchar(max),
		StartPosition int,
		Selected bit);

	CREATE TABLE #CurrentUpdateStatisticsWithClauseArguments 
	(	ID int IDENTITY,
		Argument nvarchar(max),
		Added bit DEFAULT 0);
	
	DECLARE @UniqueID TABLE (ID UNIQUEIDENTIFIER);
	DECLARE @StartMessage nvarchar(max);
	DECLARE @EndMessage nvarchar(max);
	DECLARE @DatabaseMessage nvarchar(max);
	DECLARE @ErrorMessage nvarchar(max);
	DECLARE @Severity int;
	DECLARE @StartTime datetime2 = SYSDATETIME();
	DECLARE @EndTime datetime2;
	DECLARE @SchemaName nvarchar(max) = OBJECT_SCHEMA_NAME(@@PROCID);
	DECLARE @ObjectName nvarchar(max) = OBJECT_NAME(@@PROCID);
	DECLARE @VersionTimestamp nvarchar(max) = SUBSTRING(OBJECT_DEFINITION(@@PROCID),CHARINDEX('--// Version: ',OBJECT_DEFINITION(@@PROCID)) + LEN('--// Version: ') + 1, 19);
	DECLARE @Parameters nvarchar(max);
	DECLARE @HostPlatform nvarchar(max);
	DECLARE @PartitionLevelStatistics bit;
	DECLARE @CurrentLogID UNIQUEIDENTIFIER;
	DECLARE @CurrentDBID int;
	DECLARE @CurrentDatabaseName nvarchar(max);
	DECLARE @CurrentDatabase_sp_executesql nvarchar(max);
	DECLARE @CurrentUserAccess nvarchar(max);
	DECLARE @CurrentIsReadOnly bit;
	DECLARE @CurrentDatabaseState nvarchar(max);
	DECLARE @CurrentInStandby bit;
	DECLARE @CurrentRecoveryModel nvarchar(max);
	DECLARE @CurrentIsDatabaseAccessible bit;
	DECLARE @CurrentDatabaseContext nvarchar(max);
	DECLARE @CurrentCommand nvarchar(max);
	DECLARE @CurrentCommandOutput int;
	DECLARE @CurrentCommandType nvarchar(max);
	DECLARE @CurrentComment nvarchar(max);
	DECLARE @CurrentMessage nvarchar(max);
	DECLARE @CurrentSeverity int;
	DECLARE @CurrentState int;
	DECLARE @CurrentIxID int;
	DECLARE @CurrentIxOrder int;
	DECLARE @CurrentSchemaID int;
	DECLARE @CurrentSchemaName nvarchar(max);
	DECLARE @CurrentObjectID int;
	DECLARE @CurrentObjectName nvarchar(max);
	DECLARE @CurrentObjectType nvarchar(max);
	DECLARE @CurrentIsMemoryOptimized bit;
	DECLARE @CurrentIndexID int;
	DECLARE @CurrentIndexName nvarchar(max);
	DECLARE @CurrentIndexType int;
	DECLARE @CurrentStatisticsID int;
	DECLARE @CurrentStatisticsName nvarchar(max);
	DECLARE @CurrentPartitionID bigint;
	DECLARE @CurrentPartitionNumber int;
	DECLARE @CurrentPartitionCount int;
	DECLARE @CurrentIsPartition bit;
	DECLARE @CurrentIndexExists bit;
	DECLARE @CurrentStatisticsExists bit;
	DECLARE @CurrentExtendedInfo xml;
	DECLARE @CurrentIsTimestamp bit;
	DECLARE @CurrentNoRecompute bit;
	DECLARE @CurrentIsIncremental bit;
	DECLARE @CurrentRowCount bigint;
	DECLARE @CurrentModificationCounter bigint;
	DECLARE @CurrentOnReadOnlyFileGroup bit;
	DECLARE @CurrentMaxDOP int;
	DECLARE @CurrentUpdateStatistics nvarchar(max);
	DECLARE @CurrentStatisticsSample int;
	DECLARE @CurrentStatisticsResample nvarchar(max);
	DECLARE @CurrentDelay datetime;
	DECLARE @CurrentUpdateStatisticsArgumentID int;
	DECLARE @CurrentUpdateStatisticsArgument nvarchar(max);
	DECLARE @CurrentUpdateStatisticsWithClause nvarchar(max);
	DECLARE @Error int = 0;
	DECLARE @ReturnCode int = 0;
	DECLARE @EmptyLine nvarchar(max) = CHAR(9);
	DECLARE @Version numeric(18,10) = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10));

	IF @Version >= 14
	BEGIN
		SELECT @HostPlatform = host_platform
		FROM sys.dm_os_host_info;
	END
	ELSE
	BEGIN
		SET @HostPlatform = 'Windows';
	END

	----------------------------------------------------------------------------------------------------
	--// Log initial information                                                                    //--
	----------------------------------------------------------------------------------------------------

	SET @Parameters = '@Databases = ' + ISNULL('''' + REPLACE(@Databases,'''','''''') + '''','NULL')
	SET @Parameters += ', @MaxDOP = ' + ISNULL(CAST(@MaxDOP AS nvarchar),'NULL');
	SET @Parameters += ', @UpdateStatistics = ' + ISNULL('''' + REPLACE(@UpdateStatistics,'''','''''') + '''','NULL');
	SET @Parameters += ', @OnlyModifiedStatistics = ' + ISNULL('''' + REPLACE(@OnlyModifiedStatistics,'''','''''') + '''','NULL');
	SET @Parameters += ', @StatisticsModificationLevel = ' + ISNULL(CAST(@StatisticsModificationLevel AS nvarchar),'NULL');
	SET @Parameters += ', @StatisticsSample = ' + ISNULL(CAST(@StatisticsSample AS nvarchar),'NULL');
	SET @Parameters += ', @StatisticsResample = ' + ISNULL('''' + REPLACE(@StatisticsResample,'''','''''') + '''','NULL');
	SET @Parameters += ', @PartitionLevel = ' + ISNULL('''' + REPLACE(@PartitionLevel,'''','''''') + '''','NULL');
	SET @Parameters += ', @Indexes = ' + ISNULL('''' + REPLACE(@Indexes,'''','''''') + '''','NULL');
	SET @Parameters += ', @TimeLimit = ' + ISNULL(CAST(@TimeLimit AS nvarchar),'NULL');
	SET @Parameters += ', @Delay = ' + ISNULL(CAST(@Delay AS nvarchar),'NULL');
	SET @Parameters += ', @LockTimeout = ' + ISNULL(CAST(@LockTimeout AS nvarchar),'NULL');
	SET @Parameters += ', @LockMessageSeverity = ' + ISNULL(CAST(@LockMessageSeverity AS nvarchar),'NULL');

	SET @StartMessage = 'Date and time: ' + CONVERT(nvarchar,@StartTime,120);
	RAISERROR('%s',10,1,@StartMessage) WITH NOWAIT;

	SET @StartMessage = 'Server: ' + CAST(SERVERPROPERTY('ServerName') AS nvarchar(max));
	RAISERROR('%s',10,1,@StartMessage) WITH NOWAIT;

	SET @StartMessage = 'Version: ' + CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max));
	RAISERROR('%s',10,1,@StartMessage) WITH NOWAIT;

	SET @StartMessage = 'Edition: ' + CAST(SERVERPROPERTY('Edition') AS nvarchar(max));
	RAISERROR('%s',10,1,@StartMessage) WITH NOWAIT;

	SET @StartMessage = 'Platform: ' + @HostPlatform;
	RAISERROR('%s',10,1,@StartMessage) WITH NOWAIT;

	SET @StartMessage = 'Procedure: ' + QUOTENAME(DB_NAME(DB_ID())) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@ObjectName);
	RAISERROR('%s',10,1,@StartMessage) WITH NOWAIT;

	SET @StartMessage = 'Parameters: ' + @Parameters;
	RAISERROR('%s',10,1,@StartMessage) WITH NOWAIT;

	SET @StartMessage = 'Version: ' + @VersionTimestamp;
	RAISERROR('%s',10,1,@StartMessage) WITH NOWAIT;

	RAISERROR(@EmptyLine,10,1) WITH NOWAIT;

	----------------------------------------------------------------------------------------------------
	--// Check core requirements                                                                    //--
	----------------------------------------------------------------------------------------------------

	IF NOT (SELECT [compatibility_level] FROM sys.databases WHERE database_id = DB_ID()) >= 90
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The database ' + QUOTENAME(DB_NAME(DB_ID())) + ' has to be in compatibility level 90 or higher.', 16, 1;
	END

	IF NOT (SELECT uses_ansi_nulls FROM sys.sql_modules WHERE [object_id] = @@PROCID) = 1
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'ANSI_NULLS has to be set to ON for the stored procedure.', 16, 1;
	END

	IF NOT (SELECT uses_quoted_identifier FROM sys.sql_modules WHERE [object_id] = @@PROCID) = 1
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'QUOTED_IDENTIFIER has to be set to ON for the stored procedure.', 16, 1;
	END

	IF @@TRANCOUNT <> 0
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The transaction count is not 0.', 16, 1;
	END

	----------------------------------------------------------------------------------------------------
	--// Select databases                                                                           //--
	----------------------------------------------------------------------------------------------------

	SET @Databases = REPLACE(@Databases, CHAR(10), '');
	SET @Databases = REPLACE(@Databases, CHAR(13), '');

	WHILE CHARINDEX(@StringDelimiter + ' ', @Databases) > 0 SET @Databases = REPLACE(@Databases, @StringDelimiter + ' ', @StringDelimiter);
	WHILE CHARINDEX(' ' + @StringDelimiter, @Databases) > 0 SET @Databases = REPLACE(@Databases, ' ' + @StringDelimiter, @StringDelimiter);

	SET @Databases = LTRIM(RTRIM(@Databases));

	WITH Databases1 (StartPosition, EndPosition, DatabaseItem) AS
	(
	SELECT 1 AS StartPosition,
			ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @Databases, 1), 0), LEN(@Databases) + 1) AS EndPosition,
			SUBSTRING(@Databases, 1, ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @Databases, 1), 0), LEN(@Databases) + 1) - 1) AS DatabaseItem
	WHERE @Databases IS NOT NULL
	UNION ALL
	SELECT CAST(EndPosition AS int) + 1 AS StartPosition,
			ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @Databases, EndPosition + 1), 0), LEN(@Databases) + 1) AS EndPosition,
			SUBSTRING(@Databases, EndPosition + 1, ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @Databases, EndPosition + 1), 0), LEN(@Databases) + 1) - EndPosition - 1) AS DatabaseItem
	FROM Databases1
	WHERE EndPosition < LEN(@Databases) + 1
	),
	Databases2 (DatabaseItem, StartPosition, Selected) AS
	(
	SELECT CASE WHEN DatabaseItem LIKE '-%' THEN RIGHT(DatabaseItem,LEN(DatabaseItem) - 1) ELSE DatabaseItem END AS DatabaseItem,
			StartPosition,
			CASE WHEN DatabaseItem LIKE '-%' THEN 0 ELSE 1 END AS Selected
	FROM Databases1
	),
	Databases3 (DatabaseItem, DatabaseType, StartPosition, Selected) AS
	(
	SELECT CASE WHEN DatabaseItem IN('ALL_DATABASES','SYSTEM_DATABASES','USER_DATABASES') THEN '%' ELSE DatabaseItem END AS DatabaseItem,
			CASE WHEN DatabaseItem = 'SYSTEM_DATABASES' THEN 'S' WHEN DatabaseItem = 'USER_DATABASES' THEN 'U' ELSE NULL END AS DatabaseType,
			StartPosition,
			Selected
	FROM Databases2
	),
	Databases4 (DatabaseName, DatabaseType, StartPosition, Selected) AS
	(
	SELECT CASE WHEN LEFT(DatabaseItem,1) = '[' AND RIGHT(DatabaseItem,1) = ']' THEN PARSENAME(DatabaseItem,1) ELSE DatabaseItem END AS DatabaseItem,
			DatabaseType,
			StartPosition,
			Selected
	FROM Databases3
	)
	INSERT INTO #SelectedDatabases (DatabaseName, DatabaseType, StartPosition, Selected)
	SELECT DatabaseName,
			DatabaseType,
			StartPosition,
			Selected
	FROM Databases4
	OPTION (MAXRECURSION 0);

	INSERT INTO #tmpDatabases (DatabaseName, DatabaseType, [Order], Selected, Completed)
	SELECT [name] AS DatabaseName,
			CASE WHEN name IN('master','msdb','model') OR is_distributor = 1 THEN 'S' ELSE 'U' END AS DatabaseType,
			0 AS [Order],
			0 AS Selected,
			0 AS Completed
	FROM sys.databases
	WHERE [name] <> 'tempdb'
	AND source_database_id IS NULL
	ORDER BY [name] ASC;

	UPDATE tmpDatabases
	SET tmpDatabases.Selected = SelectedDatabases.Selected
	FROM #tmpDatabases tmpDatabases
	INNER JOIN #SelectedDatabases SelectedDatabases
	ON tmpDatabases.DatabaseName LIKE REPLACE(SelectedDatabases.DatabaseName,'_','[_]')
	AND (tmpDatabases.DatabaseType = SelectedDatabases.DatabaseType OR SelectedDatabases.DatabaseType IS NULL)
	WHERE SelectedDatabases.Selected = 1;

	UPDATE tmpDatabases
	SET tmpDatabases.Selected = SelectedDatabases.Selected
	FROM #tmpDatabases tmpDatabases
	INNER JOIN #SelectedDatabases SelectedDatabases
	ON tmpDatabases.DatabaseName LIKE REPLACE(SelectedDatabases.DatabaseName,'_','[_]')
	AND (tmpDatabases.DatabaseType = SelectedDatabases.DatabaseType OR SelectedDatabases.DatabaseType IS NULL)
	WHERE SelectedDatabases.Selected = 0;

	UPDATE tmpDatabases
	SET tmpDatabases.StartPosition = SelectedDatabases2.StartPosition
	FROM #tmpDatabases tmpDatabases
	INNER JOIN (SELECT tmpDatabases.DatabaseName, MIN(SelectedDatabases.StartPosition) AS StartPosition
				FROM #tmpDatabases tmpDatabases
				INNER JOIN #SelectedDatabases SelectedDatabases
				ON tmpDatabases.DatabaseName LIKE REPLACE(SelectedDatabases.DatabaseName,'_','[_]')
				AND (tmpDatabases.DatabaseType = SelectedDatabases.DatabaseType OR SelectedDatabases.DatabaseType IS NULL)
				WHERE SelectedDatabases.Selected = 1
				GROUP BY tmpDatabases.DatabaseName) SelectedDatabases2
	ON tmpDatabases.DatabaseName = SelectedDatabases2.DatabaseName;

	IF @Databases IS NOT NULL AND (NOT EXISTS(SELECT * FROM #SelectedDatabases) OR EXISTS(SELECT * FROM #SelectedDatabases WHERE DatabaseName IS NULL OR DatabaseName = ''))
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @Databases is not supported.', 16, 1;
	END

	IF (@Databases IS NULL)
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'You need to specify one of the parameters @Databases.', 16, 2;
	END

	----------------------------------------------------------------------------------------------------
	--// Select indexes                                                                             //--
	----------------------------------------------------------------------------------------------------

	SET @Indexes = REPLACE(@Indexes, CHAR(10), '');
	SET @Indexes = REPLACE(@Indexes, CHAR(13), '');

	WHILE CHARINDEX(@StringDelimiter + ' ', @Indexes) > 0 SET @Indexes = REPLACE(@Indexes, @StringDelimiter + ' ', @StringDelimiter);
	WHILE CHARINDEX(' ' + @StringDelimiter, @Indexes) > 0 SET @Indexes = REPLACE(@Indexes, ' ' + @StringDelimiter, @StringDelimiter);

	SET @Indexes = LTRIM(RTRIM(@Indexes));

	WITH Indexes1 (StartPosition, EndPosition, IndexItem) AS
	(
	SELECT 1 AS StartPosition,
			ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @Indexes, 1), 0), LEN(@Indexes) + 1) AS EndPosition,
			SUBSTRING(@Indexes, 1, ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @Indexes, 1), 0), LEN(@Indexes) + 1) - 1) AS IndexItem
	WHERE @Indexes IS NOT NULL
	UNION ALL
	SELECT CAST(EndPosition AS int) + 1 AS StartPosition,
			ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @Indexes, EndPosition + 1), 0), LEN(@Indexes) + 1) AS EndPosition,
			SUBSTRING(@Indexes, EndPosition + 1, ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @Indexes, EndPosition + 1), 0), LEN(@Indexes) + 1) - EndPosition - 1) AS IndexItem
	FROM Indexes1
	WHERE EndPosition < LEN(@Indexes) + 1
	),
	Indexes2 (IndexItem, StartPosition, Selected) AS
	(
	SELECT CASE WHEN IndexItem LIKE '-%' THEN RIGHT(IndexItem,LEN(IndexItem) - 1) ELSE IndexItem END AS IndexItem,
			StartPosition,
			CASE WHEN IndexItem LIKE '-%' THEN 0 ELSE 1 END AS Selected
	FROM Indexes1
	),
	Indexes3 (IndexItem, StartPosition, Selected) AS
	(
	SELECT CASE WHEN IndexItem = 'ALL_INDEXES' THEN '%.%.%.%' ELSE IndexItem END AS IndexItem,
			StartPosition,
			Selected
	FROM Indexes2
	),
	Indexes4 (DatabaseName, SchemaName, ObjectName, IndexName, StartPosition, Selected) AS
	(
	SELECT CASE WHEN PARSENAME(IndexItem,4) IS NULL THEN PARSENAME(IndexItem,3) ELSE PARSENAME(IndexItem,4) END AS DatabaseName,
			CASE WHEN PARSENAME(IndexItem,4) IS NULL THEN PARSENAME(IndexItem,2) ELSE PARSENAME(IndexItem,3) END AS SchemaName,
			CASE WHEN PARSENAME(IndexItem,4) IS NULL THEN PARSENAME(IndexItem,1) ELSE PARSENAME(IndexItem,2) END AS ObjectName,
			CASE WHEN PARSENAME(IndexItem,4) IS NULL THEN '%' ELSE PARSENAME(IndexItem,1) END AS IndexName,
			StartPosition,
			Selected
	FROM Indexes3
	)
	INSERT INTO #SelectedIndexes (DatabaseName, SchemaName, ObjectName, IndexName, StartPosition, Selected)
	SELECT DatabaseName, SchemaName, ObjectName, IndexName, StartPosition, Selected
	FROM Indexes4
	OPTION (MAXRECURSION 0);

	----------------------------------------------------------------------------------------------------
	--// Check parameters                                                                           //--
	----------------------------------------------------------------------------------------------------

	IF @MaxDOP < 0 OR @MaxDOP > 64
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @MaxDOP is not supported.', 16, 1;
	END

	----------------------------------------------------------------------------------------------------

	IF @UpdateStatistics NOT IN('ALL','COLUMNS','INDEX')
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @UpdateStatistics is not supported.', 16, 1;
	END

	----------------------------------------------------------------------------------------------------

	IF @OnlyModifiedStatistics NOT IN('Y','N') OR @OnlyModifiedStatistics IS NULL
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @OnlyModifiedStatistics is not supported.', 16, 1;
	END

	----------------------------------------------------------------------------------------------------

	IF @StatisticsModificationLevel <= 0 OR @StatisticsModificationLevel > 100
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @StatisticsModificationLevel is not supported.', 16, 1
	END

	----------------------------------------------------------------------------------------------------

	IF @OnlyModifiedStatistics = 'Y' AND @StatisticsModificationLevel IS NOT NULL
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'You can only specify one of the parameters @OnlyModifiedStatistics and @StatisticsModificationLevel.', 16, 1;
	END

	----------------------------------------------------------------------------------------------------

	IF @StatisticsSample <= 0 OR @StatisticsSample  > 100
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @StatisticsSample is not supported.', 16, 1;
	END

	----------------------------------------------------------------------------------------------------

	IF @StatisticsResample NOT IN('Y','N') OR @StatisticsResample IS NULL
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @StatisticsResample is not supported.', 16, 1;
	END

	IF @StatisticsResample = 'Y' AND @StatisticsSample IS NOT NULL
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @StatisticsResample is not supported.', 16, 2;
	END

	----------------------------------------------------------------------------------------------------

	IF @PartitionLevel NOT IN('Y','N') OR @PartitionLevel IS NULL
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @PartitionLevel is not supported.', 16, 1;
	END

	----------------------------------------------------------------------------------------------------

	IF EXISTS(SELECT * FROM #SelectedIndexes WHERE DatabaseName IS NULL OR SchemaName IS NULL OR ObjectName IS NULL OR IndexName IS NULL)
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @Indexes is not supported.', 16, 1;
	END

	IF @Indexes IS NOT NULL AND NOT EXISTS(SELECT * FROM #SelectedIndexes)
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @Indexes is not supported.', 16, 2;
	END

	----------------------------------------------------------------------------------------------------

	IF @TimeLimit < 0
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @TimeLimit is not supported.', 16, 1;
	END

	----------------------------------------------------------------------------------------------------

	IF @Delay < 0
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @Delay is not supported.', 16, 1;
	END

	----------------------------------------------------------------------------------------------------

	IF @LockTimeout < 0
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @LockTimeout is not supported.', 16, 1;
	END

	----------------------------------------------------------------------------------------------------

	IF @LockMessageSeverity NOT IN(10, 16)
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @LockMessageSeverity is not supported.', 16, 1;
	END

	----------------------------------------------------------------------------------------------------

	IF @StringDelimiter IS NULL OR LEN(@StringDelimiter) > 1
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The value for the parameter @StringDelimiter is not supported.', 16, 1;
	END

	----------------------------------------------------------------------------------------------------
	--// Check that selected databases exist                                //--
	----------------------------------------------------------------------------------------------------

	SET @ErrorMessage = ''
	SELECT @ErrorMessage = @ErrorMessage + QUOTENAME(DatabaseName) + ', '
	FROM #SelectedDatabases
	WHERE DatabaseName NOT LIKE '%[%]%'
	AND DatabaseName NOT IN (SELECT DatabaseName FROM #tmpDatabases);

	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The following databases in the @Databases parameter do not exist: ' + LEFT(@ErrorMessage,LEN(@ErrorMessage)-1) + '.', 10, 1;
	END

	SET @ErrorMessage = ''
	SELECT @ErrorMessage = @ErrorMessage + QUOTENAME(DatabaseName) + ', '
	FROM #SelectedIndexes
	WHERE DatabaseName NOT LIKE '%[%]%'
	AND DatabaseName NOT IN (SELECT DatabaseName FROM #tmpDatabases);

	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The following databases in the @Indexes parameter do not exist: ' + LEFT(@ErrorMessage,LEN(@ErrorMessage)-1) + '.', 10, 1;
	END

	SET @ErrorMessage = ''
	SELECT @ErrorMessage = @ErrorMessage + QUOTENAME(DatabaseName) + ', '
	FROM #SelectedIndexes
	WHERE DatabaseName NOT LIKE '%[%]%'
	AND DatabaseName IN (SELECT DatabaseName FROM #tmpDatabases)
	AND DatabaseName NOT IN (SELECT DatabaseName FROM #tmpDatabases WHERE Selected = 1);

	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #Errors ([Message], Severity, [State])
		SELECT 'The following databases have been selected in the @Indexes parameter, but not in the @Databases parameters: ' + LEFT(@ErrorMessage,LEN(@ErrorMessage)-1) + '.', 10, 1;
	END

	----------------------------------------------------------------------------------------------------
	--// Raise errors                                                                               //--
	----------------------------------------------------------------------------------------------------

	DECLARE ErrorCursor CURSOR FAST_FORWARD FOR SELECT [Message], Severity, [State] FROM #Errors ORDER BY [ID] ASC;

	OPEN ErrorCursor;

	FETCH ErrorCursor INTO @CurrentMessage, @CurrentSeverity, @CurrentState;

	WHILE @@FETCH_STATUS = 0
	BEGIN
	RAISERROR('%s', @CurrentSeverity, @CurrentState, @CurrentMessage) WITH NOWAIT
	RAISERROR(@EmptyLine, 10, 1) WITH NOWAIT;

	FETCH NEXT FROM ErrorCursor INTO @CurrentMessage, @CurrentSeverity, @CurrentState;
	END

	CLOSE ErrorCursor;

	DEALLOCATE ErrorCursor;

	IF EXISTS (SELECT * FROM #Errors WHERE Severity >= 16)
	BEGIN
		SET @ReturnCode = 50000;
		GOTO Logging;
	END

	----------------------------------------------------------------------------------------------------
	--// Should statistics be updated on the partition level?                                       //--
	----------------------------------------------------------------------------------------------------

	SET @PartitionLevelStatistics = CASE WHEN @PartitionLevel = 'Y' AND ((@Version >= 12.05 AND @Version < 13) OR @Version >= 13.04422 OR SERVERPROPERTY('EngineEdition') IN (5,8)) THEN 1 ELSE 0 END;

	----------------------------------------------------------------------------------------------------
	--// Update database order                                                                      //--
	----------------------------------------------------------------------------------------------------

	WITH tmpDatabases AS (
	SELECT DatabaseName, [Order], ROW_NUMBER() OVER (ORDER BY DatabaseName ASC) AS RowNumber
	FROM #tmpDatabases tmpDatabases
	WHERE Selected = 1
	)
	UPDATE tmpDatabases
	SET [Order] = RowNumber;

	----------------------------------------------------------------------------------------------------
	--// Execute commands                                                                           //--
	----------------------------------------------------------------------------------------------------

	WHILE (1 = 1)
	BEGIN
		SELECT TOP 1 @CurrentDBID = ID,
					@CurrentDatabaseName = DatabaseName
		FROM #tmpDatabases
		WHERE Selected = 1
		AND Completed = 0
		ORDER BY [Order] ASC;

		IF @@ROWCOUNT = 0
		BEGIN
			BREAK;
		END

		SET @CurrentDatabase_sp_executesql = QUOTENAME(@CurrentDatabaseName) + '.sys.sp_executesql';

		SET @DatabaseMessage = 'Date and time: ' + CONVERT(nvarchar,SYSDATETIME(),120);
		RAISERROR('%s',10,1,@DatabaseMessage) WITH NOWAIT;

		SET @DatabaseMessage = 'Database: ' + QUOTENAME(@CurrentDatabaseName);
		RAISERROR('%s',10,1,@DatabaseMessage) WITH NOWAIT;

		SELECT  @CurrentUserAccess = user_access_desc,
				@CurrentIsReadOnly = is_read_only,
				@CurrentDatabaseState = state_desc,
				@CurrentInStandby = is_in_standby,
				@CurrentRecoveryModel = recovery_model_desc
		FROM sys.databases
		WHERE [name] = @CurrentDatabaseName;

		SET @DatabaseMessage = 'State: ' + @CurrentDatabaseState;
		RAISERROR('%s',10,1,@DatabaseMessage) WITH NOWAIT;

		SET @DatabaseMessage = 'Standby: ' + CASE WHEN @CurrentInStandby = 1 THEN 'Yes' ELSE 'No' END;
		RAISERROR('%s',10,1,@DatabaseMessage) WITH NOWAIT;

		SET @DatabaseMessage = 'Updateability: ' + CASE WHEN @CurrentIsReadOnly = 1 THEN 'READ_ONLY' WHEN  @CurrentIsReadOnly = 0 THEN 'READ_WRITE' END;
		RAISERROR('%s',10,1,@DatabaseMessage) WITH NOWAIT;

		SET @DatabaseMessage = 'User access: ' + @CurrentUserAccess;
		RAISERROR('%s',10,1,@DatabaseMessage) WITH NOWAIT;

		SET @DatabaseMessage = 'Recovery model: ' + @CurrentRecoveryModel;
		RAISERROR('%s',10,1,@DatabaseMessage) WITH NOWAIT;

		IF @CurrentDatabaseState = 'ONLINE' AND SERVERPROPERTY('EngineEdition') <> 5
		BEGIN
			IF EXISTS (SELECT * FROM sys.database_recovery_status WHERE database_id = DB_ID(@CurrentDatabaseName) AND database_guid IS NOT NULL)
			BEGIN
				SET @CurrentIsDatabaseAccessible = 1;
			END
			ELSE
			BEGIN
				SET @CurrentIsDatabaseAccessible = 0;
			END
		END

		IF @CurrentIsDatabaseAccessible IS NOT NULL
		BEGIN
			SET @DatabaseMessage = 'Is accessible: ' + CASE WHEN @CurrentIsDatabaseAccessible = 1 THEN 'Yes' ELSE 'No' END;
			RAISERROR('%s',10,1,@DatabaseMessage) WITH NOWAIT;
		END

		IF @CurrentDatabaseState = 'ONLINE'
		AND NOT (@CurrentUserAccess = 'SINGLE_USER' AND @CurrentIsDatabaseAccessible = 0)
		AND DATABASEPROPERTYEX(@CurrentDatabaseName,'Updateability') = 'READ_WRITE'
		BEGIN
			IF NOT EXISTS(SELECT 1 FROM dbo.UpdateStatisticsTask WHERE DatabaseName = @CurrentDatabaseName)
			BEGIN 
				--TRUNCATE TABLE dbo.UpdateStatisticsTask;
				-- Select indexes in the current database
				IF (@UpdateStatistics IS NOT NULL) AND (SYSDATETIME() < DATEADD(SECOND,@TimeLimit,@StartTime) OR @TimeLimit IS NULL)
				BEGIN
					SET @CurrentCommand = 'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;'
											+ ' SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS ID, DatabaseName, SchemaID, SchemaName, ObjectID, ObjectName, ObjectType, IsMemoryOptimized, IndexID, IndexName, IndexType, IsTimestamp, OnReadOnlyFileGroup, StatisticsID, StatisticsName, NoRecompute, IsIncremental, PartitionID, PartitionNumber, PartitionCount, [Order], Selected, Completed'
											+ ' FROM (';

					IF @UpdateStatistics IN('ALL','INDEX')
					BEGIN
						SET @CurrentCommand = @CurrentCommand + 'SELECT DB_NAME(DB_ID()) AS DatabaseName, schemas.[schema_id] AS SchemaID'
																+ ', schemas.[name] AS SchemaName'
																+ ', objects.[object_id] AS ObjectID'
																+ ', objects.[name] AS ObjectName'
																+ ', RTRIM(objects.[type]) AS ObjectType'
																+ ', ' + CASE WHEN @Version >= 12 THEN 'tables.is_memory_optimized' ELSE '0' END + ' AS IsMemoryOptimized'
																+ ', indexes.index_id AS IndexID'
																+ ', indexes.[name] AS IndexName'
																+ ', indexes.[type] AS IndexType'
																+ ', CASE WHEN EXISTS(SELECT * FROM sys.index_columns index_columns INNER JOIN sys.columns columns ON index_columns.[object_id] = columns.[object_id] AND index_columns.column_id = columns.column_id INNER JOIN sys.types types ON columns.system_type_id = types.system_type_id WHERE index_columns.[object_id] = objects.object_id AND index_columns.index_id = indexes.index_id AND types.[name] = ''timestamp'') THEN 1 ELSE 0 END AS IsTimestamp'
																+ ', CASE WHEN EXISTS (SELECT * FROM sys.indexes indexes2 INNER JOIN sys.destination_data_spaces destination_data_spaces ON indexes.data_space_id = destination_data_spaces.partition_scheme_id INNER JOIN sys.filegroups filegroups ON destination_data_spaces.data_space_id = filegroups.data_space_id WHERE filegroups.is_read_only = 1 AND indexes2.[object_id] = indexes.[object_id] AND indexes2.[index_id] = indexes.index_id' + CASE WHEN @PartitionLevel = 'Y' THEN ' AND destination_data_spaces.destination_id = partitions.partition_number' ELSE '' END + ') THEN 1'
																+ ' WHEN EXISTS (SELECT * FROM sys.indexes indexes2 INNER JOIN sys.filegroups filegroups ON indexes.data_space_id = filegroups.data_space_id WHERE filegroups.is_read_only = 1 AND indexes.[object_id] = indexes2.[object_id] AND indexes.[index_id] = indexes2.index_id) THEN 1'
																+ ' WHEN indexes.[type] = 1 AND EXISTS (SELECT * FROM sys.tables tables INNER JOIN sys.filegroups filegroups ON tables.lob_data_space_id = filegroups.data_space_id WHERE filegroups.is_read_only = 1 AND tables.[object_id] = objects.[object_id]) THEN 1 ELSE 0 END AS OnReadOnlyFileGroup'
																+ ', stats.stats_id AS StatisticsID'
																+ ', stats.name AS StatisticsName'
																+ ', stats.no_recompute AS NoRecompute'
																+ ', ' + CASE WHEN @Version >= 12 THEN 'stats.is_incremental' ELSE '0' END + ' AS IsIncremental'
																+ ', ' + CASE WHEN @PartitionLevel = 'Y' THEN 'partitions.partition_id AS PartitionID' WHEN @PartitionLevel = 'N' THEN 'NULL AS PartitionID' END
																+ ', ' + CASE WHEN @PartitionLevel = 'Y' THEN 'partitions.partition_number AS PartitionNumber' WHEN @PartitionLevel = 'N' THEN 'NULL AS PartitionNumber' END
																+ ', ' + CASE WHEN @PartitionLevel = 'Y' THEN 'IndexPartitions.partition_count AS PartitionCount' WHEN @PartitionLevel = 'N' THEN 'NULL AS PartitionCount' END
																+ ', 0 AS [Order]'
																+ ', 0 AS Selected'
																+ ', 0 AS Completed'
																+ ' FROM sys.indexes indexes'
																+ ' INNER JOIN sys.objects objects ON indexes.[object_id] = objects.[object_id]'
																+ ' INNER JOIN sys.schemas schemas ON objects.[schema_id] = schemas.[schema_id]'
																+ ' LEFT OUTER JOIN sys.tables tables ON objects.[object_id] = tables.[object_id]'
																+ ' LEFT OUTER JOIN sys.stats stats ON indexes.[object_id] = stats.[object_id] AND indexes.[index_id] = stats.[stats_id]';
						IF @PartitionLevel = 'Y'
						BEGIN
						SET @CurrentCommand = @CurrentCommand + ' LEFT OUTER JOIN sys.partitions partitions ON indexes.[object_id] = partitions.[object_id] AND indexes.index_id = partitions.index_id'
																	+ ' LEFT OUTER JOIN (SELECT partitions.[object_id], partitions.index_id, COUNT(DISTINCT partitions.partition_number) AS partition_count FROM sys.partitions partitions GROUP BY partitions.[object_id], partitions.index_id) IndexPartitions ON partitions.[object_id] = IndexPartitions.[object_id] AND partitions.[index_id] = IndexPartitions.[index_id]';
						END

						SET @CurrentCommand = @CurrentCommand + ' WHERE objects.[type] IN(''U'',''V'')'
																+ ' AND objects.is_ms_shipped = 0'
																+ ' AND indexes.[type] IN(1,2,3,4,5,6,7)'
																+ ' AND indexes.is_disabled = 0 AND indexes.is_hypothetical = 0';
					END

					IF (@UpdateStatistics = 'COLUMNS') OR @UpdateStatistics = 'ALL'
					BEGIN
						SET @CurrentCommand = @CurrentCommand + ' UNION ';
					END

					IF @UpdateStatistics IN('ALL','COLUMNS')
					BEGIN
						SET @CurrentCommand = @CurrentCommand + 'SELECT DB_NAME(DB_ID()) AS DatabaseName, schemas.[schema_id] AS SchemaID'
																+ ', schemas.[name] AS SchemaName'
																+ ', objects.[object_id] AS ObjectID'
																+ ', objects.[name] AS ObjectName'
																+ ', RTRIM(objects.[type]) AS ObjectType'
																+ ', ' + CASE WHEN @Version >= 12 THEN 'tables.is_memory_optimized' ELSE '0' END + ' AS IsMemoryOptimized'
																+ ', NULL AS IndexID, NULL AS IndexName'
																+ ', NULL AS IndexType'
																+ ', NULL AS IsTimestamp'
																+ ', NULL AS OnReadOnlyFileGroup'
																+ ', stats.stats_id AS StatisticsID'
																+ ', stats.name AS StatisticsName'
																+ ', stats.no_recompute AS NoRecompute'
																+ ', ' + CASE WHEN @Version >= 12 THEN 'stats.is_incremental' ELSE '0' END + ' AS IsIncremental'
																+ ', NULL AS PartitionID'
																+ ', ' + CASE WHEN @PartitionLevelStatistics = 1 THEN 'dm_db_incremental_stats_properties.partition_number' ELSE 'NULL' END + ' AS PartitionNumber'
																+ ', NULL AS PartitionCount'
																+ ', 0 AS [Order]'
																+ ', 0 AS Selected'
																+ ', 0 AS Completed'
																+ ' FROM sys.stats stats'
																+ ' INNER JOIN sys.objects objects ON stats.[object_id] = objects.[object_id]'
																+ ' INNER JOIN sys.schemas schemas ON objects.[schema_id] = schemas.[schema_id]'
																+ ' LEFT OUTER JOIN sys.tables tables ON objects.[object_id] = tables.[object_id]';

						IF @PartitionLevelStatistics = 1
						BEGIN
							SET @CurrentCommand = @CurrentCommand + ' OUTER APPLY sys.dm_db_incremental_stats_properties(stats.object_id, stats.stats_id) dm_db_incremental_stats_properties';
						END

						SET @CurrentCommand = @CurrentCommand + ' WHERE objects.[type] IN(''U'',''V'')'
																+ ' AND objects.is_ms_shipped = 0' 
																+ ' AND NOT EXISTS(SELECT * FROM sys.indexes indexes WHERE indexes.[object_id] = stats.[object_id] AND indexes.index_id = stats.stats_id)';
					END

					SET @CurrentCommand = @CurrentCommand + ') IndexesStatistics';

					INSERT INTO dbo.UpdateStatisticsTask (ID, DatabaseName, SchemaID, SchemaName, ObjectID, ObjectName, ObjectType, IsMemoryOptimized, IndexID, IndexName, IndexType, IsTimestamp, OnReadOnlyFileGroup, StatisticsID, StatisticsName, [NoRecompute], IsIncremental, PartitionID, PartitionNumber, PartitionCount, [Order], Selected, Completed)
					EXECUTE @CurrentDatabase_sp_executesql @stmt = @CurrentCommand;
					SET @Error = @@ERROR
					IF @Error <> 0
					BEGIN
						SET @ReturnCode = @Error
					END

					IF @Indexes IS NULL
					BEGIN
						UPDATE tmpIndexesStatistics
						SET tmpIndexesStatistics.Selected = 1
						FROM dbo.UpdateStatisticsTask tmpIndexesStatistics
						WHERE DatabaseName = @CurrentDatabaseName;
					END
					ELSE
					BEGIN
						UPDATE tmpIndexesStatistics
						SET tmpIndexesStatistics.Selected = SelectedIndexes.Selected
						FROM dbo.UpdateStatisticsTask tmpIndexesStatistics
						INNER JOIN #SelectedIndexes SelectedIndexes
						ON @CurrentDatabaseName LIKE REPLACE(SelectedIndexes.DatabaseName,'_','[_]') AND tmpIndexesStatistics.SchemaName LIKE REPLACE(SelectedIndexes.SchemaName,'_','[_]') AND tmpIndexesStatistics.ObjectName LIKE REPLACE(SelectedIndexes.ObjectName,'_','[_]') AND COALESCE(tmpIndexesStatistics.IndexName,tmpIndexesStatistics.StatisticsName) LIKE REPLACE(SelectedIndexes.IndexName,'_','[_]')
						WHERE tmpIndexesStatistics.DatabaseName = @CurrentDatabaseName AND SelectedIndexes.Selected = 1;

						UPDATE tmpIndexesStatistics
						SET tmpIndexesStatistics.Selected = SelectedIndexes.Selected
						FROM dbo.UpdateStatisticsTask tmpIndexesStatistics
						INNER JOIN #SelectedIndexes SelectedIndexes
						ON @CurrentDatabaseName LIKE REPLACE(SelectedIndexes.DatabaseName,'_','[_]') AND tmpIndexesStatistics.SchemaName LIKE REPLACE(SelectedIndexes.SchemaName,'_','[_]') AND tmpIndexesStatistics.ObjectName LIKE REPLACE(SelectedIndexes.ObjectName,'_','[_]') AND COALESCE(tmpIndexesStatistics.IndexName,tmpIndexesStatistics.StatisticsName) LIKE REPLACE(SelectedIndexes.IndexName,'_','[_]')
						WHERE tmpIndexesStatistics.DatabaseName = @CurrentDatabaseName AND SelectedIndexes.Selected = 0;

						UPDATE tmpIndexesStatistics
						SET tmpIndexesStatistics.StartPosition = SelectedIndexes2.StartPosition
						FROM dbo.UpdateStatisticsTask tmpIndexesStatistics
						INNER JOIN (SELECT tmpIndexesStatistics.SchemaName, tmpIndexesStatistics.ObjectName, tmpIndexesStatistics.IndexName, tmpIndexesStatistics.StatisticsName, MIN(SelectedIndexes.StartPosition) AS StartPosition
									FROM dbo.UpdateStatisticsTask tmpIndexesStatistics
									INNER JOIN #SelectedIndexes SelectedIndexes
									ON @CurrentDatabaseName LIKE REPLACE(SelectedIndexes.DatabaseName,'_','[_]') AND tmpIndexesStatistics.SchemaName LIKE REPLACE(SelectedIndexes.SchemaName,'_','[_]') AND tmpIndexesStatistics.ObjectName LIKE REPLACE(SelectedIndexes.ObjectName,'_','[_]') AND COALESCE(tmpIndexesStatistics.IndexName,tmpIndexesStatistics.StatisticsName) LIKE REPLACE(SelectedIndexes.IndexName,'_','[_]')
									WHERE SelectedIndexes.Selected = 1
									GROUP BY tmpIndexesStatistics.SchemaName, tmpIndexesStatistics.ObjectName, tmpIndexesStatistics.IndexName, tmpIndexesStatistics.StatisticsName) SelectedIndexes2
						ON tmpIndexesStatistics.SchemaName = SelectedIndexes2.SchemaName
						AND tmpIndexesStatistics.ObjectName = SelectedIndexes2.ObjectName
						AND (tmpIndexesStatistics.IndexName = SelectedIndexes2.IndexName OR tmpIndexesStatistics.IndexName IS NULL)
						AND (tmpIndexesStatistics.StatisticsName = SelectedIndexes2.StatisticsName OR tmpIndexesStatistics.StatisticsName IS NULL)
						WHERE tmpIndexesStatistics.DatabaseName = @CurrentDatabaseName;
					END;

					WITH tmpIndexesStatistics AS (
					SELECT SchemaName, ObjectName, [Order], ROW_NUMBER() OVER (ORDER BY StartPosition ASC, SchemaName ASC, ObjectName ASC, CASE WHEN IndexType IS NULL THEN 1 ELSE 0 END ASC, IndexType ASC, IndexName ASC, StatisticsName ASC, PartitionNumber ASC) AS RowNumber
					FROM dbo.UpdateStatisticsTask tmpIndexesStatistics
					WHERE DatabaseName = @CurrentDatabaseName AND Selected = 1
					)
					UPDATE tmpIndexesStatistics
					SET [Order] = RowNumber;
				END
			END

			SET @ErrorMessage = '';
			SELECT @ErrorMessage = @ErrorMessage + QUOTENAME(DatabaseName) + '.' + QUOTENAME(SchemaName) + '.' + QUOTENAME(ObjectName) + ', '
			FROM #SelectedIndexes SelectedIndexes
			WHERE DatabaseName = @CurrentDatabaseName
			AND SchemaName NOT LIKE '%[%]%'
			AND ObjectName NOT LIKE '%[%]%'
			AND IndexName LIKE '%[%]%'
			AND NOT EXISTS (SELECT * FROM dbo.UpdateStatisticsTask WHERE SchemaName = SelectedIndexes.SchemaName AND ObjectName = SelectedIndexes.ObjectName);
			IF @@ROWCOUNT > 0
			BEGIN
				SET @ErrorMessage = 'The following objects in the @Indexes parameter do not exist: ' + LEFT(@ErrorMessage,LEN(@ErrorMessage)-1) + '.';
				RAISERROR('%s',10,1,@ErrorMessage) WITH NOWAIT;
				SET @Error = @@ERROR;
				RAISERROR(@EmptyLine,10,1) WITH NOWAIT;
			END

			SET @ErrorMessage = '';
			SELECT @ErrorMessage = @ErrorMessage + QUOTENAME(DatabaseName) + QUOTENAME(SchemaName) + '.' + QUOTENAME(ObjectName) + '.' + QUOTENAME(IndexName) + ', '
			FROM #SelectedIndexes SelectedIndexes
			WHERE DatabaseName = @CurrentDatabaseName
			AND SchemaName NOT LIKE '%[%]%'
			AND ObjectName NOT LIKE '%[%]%'
			AND IndexName NOT LIKE '%[%]%'
			AND NOT EXISTS (SELECT * FROM dbo.UpdateStatisticsTask WHERE SchemaName = SelectedIndexes.SchemaName AND ObjectName = SelectedIndexes.ObjectName AND IndexName = SelectedIndexes.IndexName);
			IF @@ROWCOUNT > 0
			BEGIN
				SET @ErrorMessage = 'The following indexes in the @Indexes parameter do not exist: ' + LEFT(@ErrorMessage,LEN(@ErrorMessage)-1) + '.';
				RAISERROR('%s',10,1,@ErrorMessage) WITH NOWAIT;
				SET @Error = @@ERROR;
				RAISERROR(@EmptyLine,10,1) WITH NOWAIT;
			END

			WHILE (SYSDATETIME() < DATEADD(SECOND,@TimeLimit,@StartTime) OR @TimeLimit IS NULL)
			BEGIN
				SELECT TOP 1 @CurrentIxID = ID,
								@CurrentIxOrder = [Order],
								@CurrentSchemaID = SchemaID,
								@CurrentSchemaName = SchemaName,
								@CurrentObjectID = ObjectID,
								@CurrentObjectName = ObjectName,
								@CurrentObjectType = ObjectType,
								@CurrentIsMemoryOptimized = IsMemoryOptimized,
								@CurrentIndexID = IndexID,
								@CurrentIndexName = IndexName,
								@CurrentIndexType = IndexType,
								@CurrentIsTimestamp = IsTimestamp,
								@CurrentOnReadOnlyFileGroup = OnReadOnlyFileGroup,
								@CurrentStatisticsID = StatisticsID,
								@CurrentStatisticsName = StatisticsName,
								@CurrentNoRecompute = [NoRecompute],
								@CurrentIsIncremental = IsIncremental,
								@CurrentPartitionID = PartitionID,
								@CurrentPartitionNumber = PartitionNumber,
								@CurrentPartitionCount = PartitionCount
				FROM dbo.UpdateStatisticsTask
				WHERE DatabaseName = @CurrentDatabaseName
				AND Selected = 1
				AND Completed = 0
				ORDER BY [Order] ASC;

				IF @@ROWCOUNT = 0
				BEGIN
					BREAK;
				END

				-- Is the index a partition?
				IF @CurrentPartitionNumber IS NULL OR @CurrentPartitionCount = 1 BEGIN SET @CurrentIsPartition = 0 END ELSE BEGIN SET @CurrentIsPartition = 1 END;

				-- Does the statistics exist?
				IF @CurrentStatisticsID IS NOT NULL AND @UpdateStatistics IS NOT NULL
				BEGIN
					SET @CurrentCommand = '';

					IF @LockTimeout IS NOT NULL SET @CurrentCommand = 'SET LOCK_TIMEOUT ' + CAST(@LockTimeout * 1000 AS nvarchar) + '; ';

					SET @CurrentCommand += 'IF EXISTS(SELECT * FROM sys.stats stats INNER JOIN sys.objects objects ON stats.[object_id] = objects.[object_id] INNER JOIN sys.schemas schemas ON objects.[schema_id] = schemas.[schema_id] WHERE objects.[type] IN(''U'',''V'')' + ' AND schemas.[schema_id] = @ParamSchemaID AND schemas.[name] = @ParamSchemaName AND objects.[object_id] = @ParamObjectID AND objects.[name] = @ParamObjectName AND objects.[type] = @ParamObjectType AND stats.stats_id = @ParamStatisticsID AND stats.[name] = @ParamStatisticsName) BEGIN SET @ParamStatisticsExists = 1 END';

					BEGIN TRY
					EXECUTE @CurrentDatabase_sp_executesql @stmt = @CurrentCommand, @params = N'@ParamSchemaID int, @ParamSchemaName sysname, @ParamObjectID int, @ParamObjectName sysname, @ParamObjectType sysname, @ParamStatisticsID int, @ParamStatisticsName sysname, @ParamStatisticsExists bit OUTPUT', @ParamSchemaID = @CurrentSchemaID, @ParamSchemaName = @CurrentSchemaName, @ParamObjectID = @CurrentObjectID, @ParamObjectName = @CurrentObjectName, @ParamObjectType = @CurrentObjectType, @ParamStatisticsID = @CurrentStatisticsID, @ParamStatisticsName = @CurrentStatisticsName, @ParamStatisticsExists = @CurrentStatisticsExists OUTPUT;

					IF @CurrentStatisticsExists IS NULL
					BEGIN
						SET @CurrentStatisticsExists = 0;
						GOTO NoAction;
					END
					END TRY
					BEGIN CATCH
					SET @ErrorMessage = 'Msg ' + CAST(ERROR_NUMBER() AS nvarchar) + ', ' + ISNULL(ERROR_MESSAGE(),'') + CASE WHEN ERROR_NUMBER() = 1222 THEN ' The statistics ' + QUOTENAME(@CurrentStatisticsName) + ' on the object ' + QUOTENAME(@CurrentDatabaseName) + '.' + QUOTENAME(@CurrentSchemaName) + '.' + QUOTENAME(@CurrentObjectName) + ' is locked. It could not be checked if the statistics exists.' ELSE '' END;
					SET @Severity = CASE WHEN ERROR_NUMBER() IN(1205,1222) THEN @LockMessageSeverity ELSE 16 END;
					RAISERROR('%s',@Severity,1,@ErrorMessage) WITH NOWAIT;
					RAISERROR(@EmptyLine,10,1) WITH NOWAIT;

					IF NOT (ERROR_NUMBER() IN(1205,1222) AND @LockMessageSeverity = 10)
					BEGIN
						SET @ReturnCode = ERROR_NUMBER();
					END

					GOTO NoAction;
					END CATCH
				END

				-- Has the data in the statistics been modified since the statistics was last updated?
				IF @CurrentStatisticsID IS NOT NULL AND @UpdateStatistics IS NOT NULL
				BEGIN
					SET @CurrentCommand = '';

					IF @LockTimeout IS NOT NULL SET @CurrentCommand = 'SET LOCK_TIMEOUT ' + CAST(@LockTimeout * 1000 AS nvarchar) + '; ';

					IF @PartitionLevelStatistics = 1 AND @CurrentIsIncremental = 1
					BEGIN
						SET @CurrentCommand += 'SELECT @ParamRowCount = [rows], @ParamModificationCounter = modification_counter FROM sys.dm_db_incremental_stats_properties (@ParamObjectID, @ParamStatisticsID) WHERE partition_number = @ParamPartitionNumber';
					END
					ELSE
					BEGIN
						IF (@Version >= 10.504000 AND @Version < 11) OR @Version >= 11.03000
						BEGIN
							SET @CurrentCommand += 'SELECT @ParamRowCount = [rows], @ParamModificationCounter = modification_counter FROM sys.dm_db_stats_properties (@ParamObjectID, @ParamStatisticsID)';
						END
						ELSE
						BEGIN
							SET @CurrentCommand += 'SELECT @ParamRowCount = rowcnt, @ParamModificationCounter = rowmodctr FROM sys.sysindexes sysindexes WHERE sysindexes.[id] = @ParamObjectID AND sysindexes.[indid] = @ParamStatisticsID';
						END
					END

					BEGIN TRY
						EXECUTE @CurrentDatabase_sp_executesql @stmt = @CurrentCommand, @params = N'@ParamObjectID int, @ParamStatisticsID int, @ParamPartitionNumber int, @ParamRowCount bigint OUTPUT, @ParamModificationCounter bigint OUTPUT', @ParamObjectID = @CurrentObjectID, @ParamStatisticsID = @CurrentStatisticsID, @ParamPartitionNumber = @CurrentPartitionNumber, @ParamRowCount = @CurrentRowCount OUTPUT, @ParamModificationCounter = @CurrentModificationCounter OUTPUT;

						IF @CurrentRowCount IS NULL SET @CurrentRowCount = 0;
						IF @CurrentModificationCounter IS NULL SET @CurrentModificationCounter = 0;
					END TRY
					BEGIN CATCH
						SET @ErrorMessage = 'Msg ' + CAST(ERROR_NUMBER() AS nvarchar) + ', ' + ISNULL(ERROR_MESSAGE(),'') + CASE WHEN ERROR_NUMBER() = 1222 THEN ' The statistics ' + QUOTENAME(@CurrentStatisticsName) + ' on the object ' + QUOTENAME(@CurrentDatabaseName) + '.' + QUOTENAME(@CurrentSchemaName) + '.' + QUOTENAME(@CurrentObjectName) + ' is locked. The rows and modification_counter could not be checked.' ELSE '' END;
						SET @Severity = CASE WHEN ERROR_NUMBER() IN(1205,1222) THEN @LockMessageSeverity ELSE 16 END;
						RAISERROR('%s',@Severity,1,@ErrorMessage) WITH NOWAIT;
						RAISERROR(@EmptyLine,10,1) WITH NOWAIT;

						IF NOT (ERROR_NUMBER() IN(1205,1222) AND @LockMessageSeverity = 10)
						BEGIN
							SET @ReturnCode = ERROR_NUMBER();
						END

						GOTO NoAction;
					END CATCH
				END

				-- Update statistics?
				IF @CurrentStatisticsID IS NOT NULL
				AND ((@UpdateStatistics = 'ALL' AND (@CurrentIndexType IN (1,2,3,4,7) OR @CurrentIndexID IS NULL)) OR (@UpdateStatistics = 'INDEX' AND @CurrentIndexID IS NOT NULL AND @CurrentIndexType IN (1,2,3,4,7)) OR (@UpdateStatistics = 'COLUMNS' AND @CurrentIndexID IS NULL))
				AND ((@OnlyModifiedStatistics = 'N' AND @StatisticsModificationLevel IS NULL) OR (@OnlyModifiedStatistics = 'Y' AND @CurrentModificationCounter > 0) OR ((@CurrentModificationCounter * 1. / NULLIF(@CurrentRowCount,0)) * 100 >= @StatisticsModificationLevel) OR (@StatisticsModificationLevel IS NOT NULL AND @CurrentModificationCounter > 0 AND (@CurrentModificationCounter >= SQRT(@CurrentRowCount * 1000))) OR (@CurrentIsMemoryOptimized = 1 AND NOT (@Version >= 13 OR SERVERPROPERTY('EngineEdition') IN (5,8))))
				AND (@CurrentIsPartition = 0 OR (@CurrentIsPartition = 1 AND (@CurrentPartitionNumber = @CurrentPartitionCount OR (@PartitionLevelStatistics = 1 AND @CurrentIsIncremental = 1))))
				BEGIN
					SET @CurrentUpdateStatistics = 'Y';
				END
				ELSE
				BEGIN
					SET @CurrentUpdateStatistics = 'N';
				END

				SET @CurrentStatisticsSample = @StatisticsSample;
				SET @CurrentStatisticsResample = @StatisticsResample;

				-- Memory-optimized tables only supports FULLSCAN and RESAMPLE in SQL Server 2014
				IF @CurrentIsMemoryOptimized = 1 AND NOT (@Version >= 13 OR SERVERPROPERTY('EngineEdition') IN (5,8)) AND (@CurrentStatisticsSample <> 100 OR @CurrentStatisticsSample IS NULL)
				BEGIN
					SET @CurrentStatisticsSample = NULL;
					SET @CurrentStatisticsResample = 'Y';
				END

				-- Incremental statistics only supports RESAMPLE
				IF @PartitionLevelStatistics = 1 AND @CurrentIsIncremental = 1
				BEGIN
					SET @CurrentStatisticsSample = NULL;
					SET @CurrentStatisticsResample = 'Y';
				END

				SET @CurrentMaxDOP = @MaxDOP;

				-- Create statistics comment
				IF @CurrentStatisticsID IS NOT NULL
				BEGIN
					SET @CurrentComment = 'ObjectType: ' + CASE WHEN @CurrentObjectType = 'U' THEN 'Table' WHEN @CurrentObjectType = 'V' THEN 'View' ELSE 'N/A' END + ', ';
					SET @CurrentComment += 'IndexType: ' + CASE WHEN @CurrentIndexID IS NOT NULL THEN 'Index' ELSE 'Column' END + ', ';
					IF @CurrentIndexID IS NOT NULL SET @CurrentComment += 'IndexType: ' + CASE WHEN @CurrentIndexType = 1 THEN 'Clustered' WHEN @CurrentIndexType = 2 THEN 'NonClustered' WHEN @CurrentIndexType = 3 THEN 'XML' WHEN @CurrentIndexType = 4 THEN 'Spatial' WHEN @CurrentIndexType = 5 THEN 'Clustered Columnstore' WHEN @CurrentIndexType = 6 THEN 'NonClustered Columnstore' WHEN @CurrentIndexType = 7 THEN 'NonClustered Hash' ELSE 'N/A' END + ', ';
					SET @CurrentComment += 'Incremental: ' + CASE WHEN @CurrentIsIncremental = 1 THEN 'Y' WHEN @CurrentIsIncremental = 0 THEN 'N' ELSE 'N/A' END + ', ';
					SET @CurrentComment += 'RowCount: ' + ISNULL(CAST(@CurrentRowCount AS nvarchar),'N/A') + ', ';
					SET @CurrentComment += 'ModificationCounter: ' + ISNULL(CAST(@CurrentModificationCounter AS nvarchar),'N/A');
				END

				IF @CurrentStatisticsID IS NOT NULL AND (@CurrentRowCount IS NOT NULL OR @CurrentModificationCounter IS NOT NULL)
				BEGIN
					SET @CurrentExtendedInfo = (SELECT *
											FROM (SELECT CAST(@CurrentRowCount AS nvarchar) AS [RowCount],
															CAST(@CurrentModificationCounter AS nvarchar) AS ModificationCounter
											) ExtendedInfo FOR XML RAW('ExtendedInfo'), ELEMENTS);
				END

				IF @CurrentStatisticsID IS NOT NULL AND @CurrentUpdateStatistics = 'Y' AND (SYSDATETIME() < DATEADD(SECOND,@TimeLimit,@StartTime) OR @TimeLimit IS NULL)
				BEGIN
					SET @CurrentDatabaseContext = @CurrentDatabaseName;

					SET @CurrentCommandType = 'UPDATE_STATISTICS';

					SET @CurrentCommand = '';
					IF @LockTimeout IS NOT NULL SET @CurrentCommand = 'SET LOCK_TIMEOUT ' + CAST(@LockTimeout * 1000 AS nvarchar) + '; ';
					SET @CurrentCommand += 'UPDATE STATISTICS ' + QUOTENAME(@CurrentSchemaName) + '.' + QUOTENAME(@CurrentObjectName) + ' ' + QUOTENAME(@CurrentStatisticsName);

					IF @CurrentMaxDOP IS NOT NULL AND ((@Version >= 12.06024 AND @Version < 13) OR (@Version >= 13.05026 AND @Version < 14) OR @Version >= 14.030154)
					BEGIN
						INSERT INTO #CurrentUpdateStatisticsWithClauseArguments (Argument)
						SELECT 'MAXDOP = ' + CAST(@CurrentMaxDOP AS nvarchar);
					END

					IF @CurrentStatisticsSample = 100
					BEGIN
						INSERT INTO #CurrentUpdateStatisticsWithClauseArguments (Argument)
						SELECT 'FULLSCAN';
					END

					IF @CurrentStatisticsSample IS NOT NULL AND @CurrentStatisticsSample <> 100
					BEGIN
						INSERT INTO #CurrentUpdateStatisticsWithClauseArguments (Argument)
						SELECT 'SAMPLE ' + CAST(@CurrentStatisticsSample AS nvarchar) + ' PERCENT';
					END

					IF @CurrentStatisticsResample = 'Y'
					BEGIN
						INSERT INTO #CurrentUpdateStatisticsWithClauseArguments (Argument)
						SELECT 'RESAMPLE';
					END

					IF @CurrentNoRecompute = 1
					BEGIN
						INSERT INTO #CurrentUpdateStatisticsWithClauseArguments (Argument)
						SELECT 'NORECOMPUTE';
					END

					IF EXISTS (SELECT * FROM #CurrentUpdateStatisticsWithClauseArguments)
					BEGIN
						SET @CurrentUpdateStatisticsWithClause = ' WITH';

						WHILE (1 = 1)
						BEGIN
							SELECT TOP 1 @CurrentUpdateStatisticsArgumentID = ID,
										@CurrentUpdateStatisticsArgument = Argument
							FROM #CurrentUpdateStatisticsWithClauseArguments
							WHERE Added = 0
							ORDER BY ID ASC;

							IF @@ROWCOUNT = 0
							BEGIN
								BREAK;
							END

							SET @CurrentUpdateStatisticsWithClause = @CurrentUpdateStatisticsWithClause + ' ' + @CurrentUpdateStatisticsArgument + ',';

							UPDATE #CurrentUpdateStatisticsWithClauseArguments
							SET Added = 1
							WHERE [ID] = @CurrentUpdateStatisticsArgumentID;
						END

						SET @CurrentUpdateStatisticsWithClause = LEFT(@CurrentUpdateStatisticsWithClause,LEN(@CurrentUpdateStatisticsWithClause) - 1);
					END

					IF @CurrentUpdateStatisticsWithClause IS NOT NULL SET @CurrentCommand += @CurrentUpdateStatisticsWithClause;

					IF @PartitionLevelStatistics = 1 AND @CurrentIsIncremental = 1 AND @CurrentPartitionNumber IS NOT NULL SET @CurrentCommand += ' ON PARTITIONS(' + CAST(@CurrentPartitionNumber AS nvarchar(max)) + ')';

					----------------------------------------------------------------------------------------------------
					--// Log initial information                                                                    //--
					----------------------------------------------------------------------------------------------------

					SET @StartMessage = 'Date and time: ' + CONVERT(nvarchar,@StartTime,120);
					RAISERROR('%s',10,1,@StartMessage) WITH NOWAIT;

					SET @StartMessage = 'Database context: ' + QUOTENAME(@CurrentDatabaseName);
					RAISERROR('%s',10,1,@StartMessage) WITH NOWAIT;

					SET @StartMessage = 'Command: ' + @CurrentCommand;
					RAISERROR('%s',10,1,@StartMessage) WITH NOWAIT;

					IF @CurrentComment IS NOT NULL
					BEGIN
						SET @StartMessage = 'Comment: ' + @CurrentComment;
						RAISERROR('%s',10,1,@StartMessage) WITH NOWAIT;
					END

					IF @LogToTable = 'Y'
					BEGIN
						INSERT INTO dbo.UpdateStatisticsLog (DatabaseName, SchemaName, ObjectName, ObjectType, IndexName, IndexType, StatisticsName, PartitionNumber, ExtendedInfo, CommandType, Command, StartTime)
						OUTPUT inserted.ID INTO @UniqueID
						VALUES (@CurrentDatabaseName, @CurrentSchemaName, @CurrentObjectName, @CurrentObjectType, @CurrentIndexName, @CurrentIndexType, @CurrentStatisticsName, @CurrentPartitionNumber, @CurrentExtendedInfo, @CurrentCommandType, @CurrentCommand, @StartTime);
						
						SET @CurrentLogID = (SELECT TOP 1 ID FROM @UniqueID);
						DELETE FROM @UniqueID;
					END

					----------------------------------------------------------------------------------------------------
					--// Execute command                                                                            //--
					----------------------------------------------------------------------------------------------------

					BEGIN TRY
						EXECUTE @CurrentDatabase_sp_executesql @stmt = @CurrentCommand;
					END TRY
					BEGIN CATCH
						SET @Error = ERROR_NUMBER();
						SET @ErrorMessage = 'Msg ' + CAST(ERROR_NUMBER() AS nvarchar) + ', ' + ISNULL(ERROR_MESSAGE(),'');
						SET @Severity = CASE WHEN ERROR_NUMBER() IN(1205,1222) THEN @LockMessageSeverity ELSE 16 END;
						RAISERROR('%s',@Severity,1,@ErrorMessage) WITH NOWAIT;

						IF NOT (ERROR_NUMBER() IN(1205,1222) AND @LockMessageSeverity = 10)
						BEGIN
						SET @ReturnCode = ERROR_NUMBER();
						END
					END CATCH

					----------------------------------------------------------------------------------------------------
					--// Log completing information                                                                 //--
					----------------------------------------------------------------------------------------------------

					SET @EndTime = SYSDATETIME();

					SET @EndMessage = 'Outcome: ' + CASE WHEN @Error = 0 THEN 'Succeeded' ELSE 'Failed' END;
					RAISERROR('%s',10,1,@EndMessage) WITH NOWAIT;

					SET @EndMessage = 'Duration: ' + CASE WHEN (DATEDIFF(SECOND,@StartTime,@EndTime) / (24 * 3600)) > 0 THEN CAST((DATEDIFF(SECOND,@StartTime,@EndTime) / (24 * 3600)) AS nvarchar) + '.' ELSE '' END + CONVERT(nvarchar,DATEADD(SECOND,DATEDIFF(SECOND,@StartTime,@EndTime),'1900-01-01'),108);
					RAISERROR('%s',10,1,@EndMessage) WITH NOWAIT;

					SET @EndMessage = 'Date and time: ' + CONVERT(nvarchar,@EndTime,120);
					RAISERROR('%s',10,1,@EndMessage) WITH NOWAIT;

					RAISERROR(@EmptyLine,10,1) WITH NOWAIT;

					IF @LogToTable = 'Y'
					BEGIN
						UPDATE dbo.UpdateStatisticsLog
						SET EndTime = @EndTime,
							ErrorNumber = @Error,
							ErrorMessage = @ErrorMessage
						WHERE ID = @CurrentLogID;
					END

					IF @Error <> 0 SET @CurrentCommandOutput = @Error;
					IF @CurrentCommandOutput <> 0 SET @ReturnCode = @CurrentCommandOutput;
				END

				NoAction:

				-- Update that the index or statistics is completed
				UPDATE dbo.UpdateStatisticsTask
				SET Completed = 1
				WHERE Selected = 1
				AND Completed = 0
				AND [Order] = @CurrentIxOrder
				AND ID = @CurrentIxID;

				-- Clear variables
				SET @CurrentLogID = NULL;
				SET @CurrentDatabaseContext = NULL;
				SET @CurrentCommand = NULL;
				SET @CurrentCommandOutput = NULL;
				SET @CurrentCommandType = NULL;
				SET @CurrentComment = NULL;
				SET @CurrentExtendedInfo = NULL;
				SET @CurrentIxID = NULL;
				SET @CurrentIxOrder = NULL;
				SET @CurrentSchemaID = NULL;
				SET @CurrentSchemaName = NULL;
				SET @CurrentObjectID = NULL;
				SET @CurrentObjectName = NULL;
				SET @CurrentObjectType = NULL;
				SET @CurrentIsMemoryOptimized = NULL;
				SET @CurrentIndexID = NULL;
				SET @CurrentIndexName = NULL;
				SET @CurrentIndexType = NULL;
				SET @CurrentStatisticsID = NULL;
				SET @CurrentStatisticsName = NULL;
				SET @CurrentPartitionID = NULL;
				SET @CurrentPartitionNumber = NULL;
				SET @CurrentPartitionCount = NULL;
				SET @CurrentIsPartition = NULL;
				SET @CurrentIndexExists = NULL;
				SET @CurrentStatisticsExists = NULL;
				SET @CurrentIsTimestamp = NULL;
				SET @CurrentNoRecompute = NULL;
				SET @CurrentIsIncremental = NULL;
				SET @CurrentRowCount = NULL;
				SET @CurrentModificationCounter = NULL;
				SET @CurrentOnReadOnlyFileGroup = NULL;
				SET @CurrentMaxDOP = NULL;
				SET @CurrentUpdateStatistics = NULL;
				SET @CurrentStatisticsSample = NULL;
				SET @CurrentStatisticsResample = NULL;
				SET @CurrentUpdateStatisticsArgumentID = NULL;
				SET @CurrentUpdateStatisticsArgument = NULL;
				SET @CurrentUpdateStatisticsWithClause = NULL;

				DELETE FROM #CurrentUpdateStatisticsWithClauseArguments;

				IF @Delay > 0
				BEGIN
					SET @CurrentDelay = DATEADD(ss,@Delay,'1900-01-01')
					WAITFOR DELAY @CurrentDelay
				END
			END
		END

		IF @CurrentDatabaseState = 'SUSPECT'
		BEGIN
			SET @ErrorMessage = 'The database ' + QUOTENAME(@CurrentDatabaseName) + ' is in a SUSPECT state.'
			RAISERROR('%s',16,1,@ErrorMessage) WITH NOWAIT
			RAISERROR(@EmptyLine,10,1) WITH NOWAIT
			SET @Error = @@ERROR
		END

		-- Update that the database is completed
		UPDATE #tmpDatabases
		SET Completed = 1
		WHERE Selected = 1
		AND Completed = 0
		AND ID = @CurrentDBID;

		-- Remove unselected indexes or statistics
		DELETE FROM dbo.UpdateStatisticsTask
		WHERE DatabaseName = @CurrentDatabaseName
		AND Selected = 0
		AND Completed = 0;

		-- Clear variables
		SET @CurrentDBID = NULL;
		SET @CurrentDatabaseName = NULL;
		SET @CurrentDatabase_sp_executesql = NULL;
		SET @CurrentUserAccess = NULL;
		SET @CurrentIsReadOnly = NULL;
		SET @CurrentDatabaseState = NULL;
		SET @CurrentInStandby = NULL;
		SET @CurrentRecoveryModel = NULL;
		SET @CurrentIsDatabaseAccessible = NULL;
		SET @CurrentCommand = NULL;
	END

	IF NOT EXISTS (SELECT 1 FROM dbo.UpdateStatisticsTask WHERE Completed = 0)
	BEGIN
		TRUNCATE TABLE dbo.UpdateStatisticsTask;
	END

	----------------------------------------------------------------------------------------------------
	--// Log completing information                                                                 //--
	----------------------------------------------------------------------------------------------------

	Logging:
	SET @EndMessage = 'Date and time: ' + CONVERT(nvarchar,SYSDATETIME(),120)
	RAISERROR('%s',10,1,@EndMessage) WITH NOWAIT

	RAISERROR(@EmptyLine,10,1) WITH NOWAIT

	IF @ReturnCode <> 0
	BEGIN
		RETURN @ReturnCode;
	END
END
GO


