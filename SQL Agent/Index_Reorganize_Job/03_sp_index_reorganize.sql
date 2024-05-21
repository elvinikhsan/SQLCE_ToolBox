USE [master]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_index_reorganize]
(	@Databases nvarchar(max) = NULL,
	@FragmentationLow nvarchar(max) = NULL,
	@FragmentationMedium nvarchar(max) = 'INDEX_REORGANIZE',
	@FragmentationHigh nvarchar(max) = 'INDEX_REORGANIZE',
	@FragmentationLevel1 int = 5,
	@FragmentationLevel2 int = 30,
	@MinNumberOfPages int = 1000,
	@MaxNumberOfPages int = NULL,
	@LOBCompaction nvarchar(max) = 'Y',
	@PartitionLevel nvarchar(max) = 'Y',
	@Indexes nvarchar(max) = NULL,
	@TimeLimit int = NULL,
	@Delay int = NULL,
	@LockTimeout int = NULL,
	@LockMessageSeverity int = 16,
	@StringDelimiter nvarchar(max) = ',',
	@LogToTable nvarchar(max) = 'Y'
)
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

	CREATE TABLE #Actions ([Action] nvarchar(max));

	CREATE TABLE #ActionsPreferred (FragmentationGroup nvarchar(max),
									[Priority] int,
									[Action] nvarchar(max));

	CREATE TABLE #CurrentActionsAllowed ([Action] nvarchar(max));

	CREATE TABLE #CurrentAlterIndexWithClauseArguments (ID int IDENTITY,
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
	DECLARE @CurrentExtendedInfo xml;
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
	DECLARE @CurrentAllowPageLocks bit; 
	DECLARE @CurrentPartitionID bigint;
	DECLARE @CurrentPartitionNumber int;
	DECLARE @CurrentPartitionCount int;
	DECLARE @CurrentIsPartition bit;
	DECLARE @CurrentIndexExists bit;
	DECLARE @CurrentOnReadOnlyFileGroup bit;
	DECLARE @CurrentResumableIndexOperation bit;
	DECLARE @CurrentFragmentationLevel float;
	DECLARE @CurrentPageCount bigint;
	DECLARE @CurrentFragmentationGroup nvarchar(max);
	DECLARE @CurrentAction nvarchar(max);
	DECLARE @CurrentDelay datetime;
	DECLARE @CurrentAlterIndexArgumentID int;
	DECLARE @CurrentAlterIndexArgument nvarchar(max);
	DECLARE @CurrentAlterIndexWithClause nvarchar(max);
	DECLARE @Error int = 0;
	DECLARE @ReturnCode int = 0;
	DECLARE @EmptyLine nvarchar(max) = CHAR(9);
	DECLARE @Version numeric(18,10) = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10));

	INSERT INTO #Actions([Action]) VALUES('INDEX_REORGANIZE');

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

	SET @Parameters = '@Databases = ' + ISNULL('''' + REPLACE(@Databases,'''','''''') + '''','NULL');
	SET @Parameters += ', @FragmentationLow = ' + ISNULL('''' + REPLACE(@FragmentationLow,'''','''''') + '''','NULL');
	SET @Parameters += ', @FragmentationMedium = ' + ISNULL('''' + REPLACE(@FragmentationMedium,'''','''''') + '''','NULL');
	SET @Parameters += ', @FragmentationHigh = ' + ISNULL('''' + REPLACE(@FragmentationHigh,'''','''''') + '''','NULL');
	SET @Parameters += ', @FragmentationLevel1 = ' + ISNULL(CAST(@FragmentationLevel1 AS nvarchar),'NULL');
	SET @Parameters += ', @FragmentationLevel2 = ' + ISNULL(CAST(@FragmentationLevel2 AS nvarchar),'NULL');
	SET @Parameters += ', @MinNumberOfPages = ' + ISNULL(CAST(@MinNumberOfPages AS nvarchar),'NULL');
	SET @Parameters += ', @MaxNumberOfPages = ' + ISNULL(CAST(@MaxNumberOfPages AS nvarchar),'NULL');
	SET @Parameters += ', @LOBCompaction = ' + ISNULL('''' + REPLACE(@LOBCompaction,'''','''''') + '''','NULL');
	SET @Parameters += ', @PartitionLevel = ' + ISNULL('''' + REPLACE(@PartitionLevel,'''','''''') + '''','NULL');
	SET @Parameters += ', @Indexes = ' + ISNULL('''' + REPLACE(@Indexes,'''','''''') + '''','NULL');
	SET @Parameters += ', @TimeLimit = ' + ISNULL(CAST(@TimeLimit AS nvarchar),'NULL');
	SET @Parameters += ', @Delay = ' + ISNULL(CAST(@Delay AS nvarchar),'NULL');
	SET @Parameters += ', @LockTimeout = ' + ISNULL(CAST(@LockTimeout AS nvarchar),'NULL');
	SET @Parameters += ', @LockMessageSeverity = ' + ISNULL(CAST(@LockMessageSeverity AS nvarchar),'NULL');
	SET @Parameters += ', @StringDelimiter = ' + ISNULL('''' + REPLACE(@StringDelimiter,'''','''''') + '''','NULL');
	SET @Parameters += ', @LogToTable = ' + ISNULL('''' + REPLACE(@LogToTable,'''','''''') + '''','NULL');

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
	--// Select actions                                                                             //--
	----------------------------------------------------------------------------------------------------

	SET @FragmentationLow = REPLACE(@FragmentationLow, @StringDelimiter + ' ', @StringDelimiter);

	WITH FragmentationLow (StartPosition, EndPosition, [Action]) AS
	(
	SELECT 1 AS StartPosition,
			ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @FragmentationLow, 1), 0), LEN(@FragmentationLow) + 1) AS EndPosition,
			SUBSTRING(@FragmentationLow, 1, ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @FragmentationLow, 1), 0), LEN(@FragmentationLow) + 1) - 1) AS [Action]
	WHERE @FragmentationLow IS NOT NULL
	UNION ALL
	SELECT CAST(EndPosition AS int) + 1 AS StartPosition,
			ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @FragmentationLow, EndPosition + 1), 0), LEN(@FragmentationLow) + 1) AS EndPosition,
			SUBSTRING(@FragmentationLow, EndPosition + 1, ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @FragmentationLow, EndPosition + 1), 0), LEN(@FragmentationLow) + 1) - EndPosition - 1) AS [Action]
	FROM FragmentationLow
	WHERE EndPosition < LEN(@FragmentationLow) + 1
	)
	INSERT INTO #ActionsPreferred(FragmentationGroup, [Priority], [Action])
	SELECT 'Low' AS FragmentationGroup,
			ROW_NUMBER() OVER(ORDER BY StartPosition ASC) AS [Priority],
			[Action]
	FROM FragmentationLow
	OPTION (MAXRECURSION 0)

	SET @FragmentationMedium = REPLACE(@FragmentationMedium, @StringDelimiter + ' ', @StringDelimiter);

	WITH FragmentationMedium (StartPosition, EndPosition, [Action]) AS
	(
	SELECT 1 AS StartPosition,
			ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @FragmentationMedium, 1), 0), LEN(@FragmentationMedium) + 1) AS EndPosition,
			SUBSTRING(@FragmentationMedium, 1, ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @FragmentationMedium, 1), 0), LEN(@FragmentationMedium) + 1) - 1) AS [Action]
	WHERE @FragmentationMedium IS NOT NULL
	UNION ALL
	SELECT CAST(EndPosition AS int) + 1 AS StartPosition,
			ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @FragmentationMedium, EndPosition + 1), 0), LEN(@FragmentationMedium) + 1) AS EndPosition,
			SUBSTRING(@FragmentationMedium, EndPosition + 1, ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @FragmentationMedium, EndPosition + 1), 0), LEN(@FragmentationMedium) + 1) - EndPosition - 1) AS [Action]
	FROM FragmentationMedium
	WHERE EndPosition < LEN(@FragmentationMedium) + 1
	)
	INSERT INTO #ActionsPreferred(FragmentationGroup, [Priority], [Action])
	SELECT 'Medium' AS FragmentationGroup,
			ROW_NUMBER() OVER(ORDER BY StartPosition ASC) AS [Priority],
			[Action]
	FROM FragmentationMedium
	OPTION (MAXRECURSION 0)

	SET @FragmentationHigh = REPLACE(@FragmentationHigh, @StringDelimiter + ' ', @StringDelimiter);

	WITH FragmentationHigh (StartPosition, EndPosition, [Action]) AS
	(
	SELECT 1 AS StartPosition,
			ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @FragmentationHigh, 1), 0), LEN(@FragmentationHigh) + 1) AS EndPosition,
			SUBSTRING(@FragmentationHigh, 1, ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @FragmentationHigh, 1), 0), LEN(@FragmentationHigh) + 1) - 1) AS [Action]
	WHERE @FragmentationHigh IS NOT NULL
	UNION ALL
	SELECT CAST(EndPosition AS int) + 1 AS StartPosition,
			ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @FragmentationHigh, EndPosition + 1), 0), LEN(@FragmentationHigh) + 1) AS EndPosition,
			SUBSTRING(@FragmentationHigh, EndPosition + 1, ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @FragmentationHigh, EndPosition + 1), 0), LEN(@FragmentationHigh) + 1) - EndPosition - 1) AS [Action]
	FROM FragmentationHigh
	WHERE EndPosition < LEN(@FragmentationHigh) + 1
	)
	INSERT INTO #ActionsPreferred(FragmentationGroup, [Priority], [Action])
	SELECT 'High' AS FragmentationGroup,
			ROW_NUMBER() OVER(ORDER BY StartPosition ASC) AS [Priority],
			[Action]
	FROM FragmentationHigh
	OPTION (MAXRECURSION 0)

	----------------------------------------------------------------------------------------------------
	--// Check input parameters                                                                     //--
	----------------------------------------------------------------------------------------------------

	IF EXISTS (SELECT [Action] FROM #ActionsPreferred WHERE FragmentationGroup = 'Low' AND [Action] NOT IN(SELECT * FROM #Actions))
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @FragmentationLow is not supported.', 16, 1
	END

	IF EXISTS (SELECT * FROM #ActionsPreferred WHERE FragmentationGroup = 'Low' GROUP BY [Action] HAVING COUNT(*) > 1)
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @FragmentationLow is not supported.', 16, 2
	END

	----------------------------------------------------------------------------------------------------

	IF EXISTS (SELECT [Action] FROM #ActionsPreferred WHERE FragmentationGroup = 'Medium' AND [Action] NOT IN(SELECT * FROM #Actions))
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @FragmentationMedium is not supported.', 16, 1
	END

	IF EXISTS (SELECT * FROM #ActionsPreferred WHERE FragmentationGroup = 'Medium' GROUP BY [Action] HAVING COUNT(*) > 1)
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @FragmentationMedium is not supported.', 16, 2
	END

	----------------------------------------------------------------------------------------------------

	IF EXISTS (SELECT [Action] FROM #ActionsPreferred WHERE FragmentationGroup = 'High' AND [Action] NOT IN(SELECT * FROM #Actions))
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @FragmentationHigh is not supported.', 16, 1
	END

	IF EXISTS (SELECT * FROM #ActionsPreferred WHERE FragmentationGroup = 'High' GROUP BY [Action] HAVING COUNT(*) > 1)
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @FragmentationHigh is not supported.', 16, 2
	END

	----------------------------------------------------------------------------------------------------

	IF @FragmentationLevel1 <= 0 OR @FragmentationLevel1 >= 100 OR @FragmentationLevel1 IS NULL
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @FragmentationLevel1 is not supported.', 16, 1
	END

	IF @FragmentationLevel1 >= @FragmentationLevel2
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @FragmentationLevel1 is not supported.', 16, 2
	END

	----------------------------------------------------------------------------------------------------

	IF @FragmentationLevel2 <= 0 OR @FragmentationLevel2 >= 100 OR @FragmentationLevel2 IS NULL
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @FragmentationLevel2 is not supported.', 16, 1
	END

	IF @FragmentationLevel2 <= @FragmentationLevel1
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @FragmentationLevel2 is not supported.', 16, 2
	END

	----------------------------------------------------------------------------------------------------

	IF @MinNumberOfPages < 0 OR @MinNumberOfPages IS NULL
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @MinNumberOfPages is not supported.', 16, 1
	END

	----------------------------------------------------------------------------------------------------

	IF @MaxNumberOfPages < 0
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @MaxNumberOfPages is not supported.', 16, 1
	END

	----------------------------------------------------------------------------------------------------

	IF @LOBCompaction NOT IN('Y','N') OR @LOBCompaction IS NULL
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @LOBCompaction is not supported.', 16, 1
	END

	----------------------------------------------------------------------------------------------------

	IF @PartitionLevel NOT IN('Y','N') OR @PartitionLevel IS NULL
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @PartitionLevel is not supported.', 16, 1
	END

	----------------------------------------------------------------------------------------------------

	IF EXISTS(SELECT * FROM #SelectedIndexes WHERE DatabaseName IS NULL OR SchemaName IS NULL OR ObjectName IS NULL OR IndexName IS NULL)
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @Indexes is not supported.', 16, 1
	END

	IF @Indexes IS NOT NULL AND NOT EXISTS(SELECT * FROM #SelectedIndexes)
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @Indexes is not supported.', 16, 2
	END

	----------------------------------------------------------------------------------------------------

	IF @TimeLimit < 0
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @TimeLimit is not supported.', 16, 1
	END

	----------------------------------------------------------------------------------------------------

	IF @Delay < 0
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @Delay is not supported.', 16, 1
	END

	----------------------------------------------------------------------------------------------------

	IF @LockTimeout < 0
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @LockTimeout is not supported.', 16, 1
	END

	----------------------------------------------------------------------------------------------------

	IF @LockMessageSeverity NOT IN(10, 16)
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @LockMessageSeverity is not supported.', 16, 1
	END

	----------------------------------------------------------------------------------------------------

	IF @StringDelimiter IS NULL OR LEN(@StringDelimiter) > 1
	BEGIN
	INSERT INTO #Errors ([Message], Severity, [State])
	SELECT 'The value for the parameter @StringDelimiter is not supported.', 16, 1
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
	END;

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
			IF NOT EXISTS(SELECT 1 FROM dbo.IndexReorganizeTask WHERE DatabaseName = @CurrentDatabaseName)
			BEGIN 
				--TRUNCATE TABLE dbo.IndexReorganizeTask;
				-- Select indexes in the current database
				IF (EXISTS(SELECT 1 FROM #ActionsPreferred)) AND (SYSDATETIME() < DATEADD(SECOND,@TimeLimit,@StartTime) OR @TimeLimit IS NULL)
				BEGIN
					SET @CurrentCommand = 'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;'
											+ ' SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS ID, DatabaseName, SchemaID, SchemaName, ObjectID, ObjectName, ObjectType, IsMemoryOptimized, IndexID, IndexName, IndexType, AllowPageLocks, OnReadOnlyFileGroup, ResumableIndexOperation, PartitionID, PartitionNumber, PartitionCount, [Order], Selected, Completed'
											+ ' FROM (';

					IF EXISTS(SELECT 1 FROM #ActionsPreferred)
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
																+ ', indexes.allow_page_locks AS AllowPageLocks'
																+ ', CASE WHEN EXISTS (SELECT * FROM sys.indexes indexes2 INNER JOIN sys.destination_data_spaces destination_data_spaces ON indexes.data_space_id = destination_data_spaces.partition_scheme_id INNER JOIN sys.filegroups filegroups ON destination_data_spaces.data_space_id = filegroups.data_space_id WHERE filegroups.is_read_only = 1 AND indexes2.[object_id] = indexes.[object_id] AND indexes2.[index_id] = indexes.index_id' + CASE WHEN @PartitionLevel = 'Y' THEN ' AND destination_data_spaces.destination_id = partitions.partition_number' ELSE '' END + ') THEN 1'
																+ ' WHEN EXISTS (SELECT * FROM sys.indexes indexes2 INNER JOIN sys.filegroups filegroups ON indexes.data_space_id = filegroups.data_space_id WHERE filegroups.is_read_only = 1 AND indexes.[object_id] = indexes2.[object_id] AND indexes.[index_id] = indexes2.index_id) THEN 1'
																+ ' WHEN indexes.[type] = 1 AND EXISTS (SELECT * FROM sys.tables tables INNER JOIN sys.filegroups filegroups ON tables.lob_data_space_id = filegroups.data_space_id WHERE filegroups.is_read_only = 1 AND tables.[object_id] = objects.[object_id]) THEN 1 ELSE 0 END AS OnReadOnlyFileGroup'
																+ ', ' + CASE WHEN @Version >= 14 THEN 'CASE WHEN EXISTS(SELECT * FROM sys.index_resumable_operations index_resumable_operations WHERE state_desc = ''PAUSED'' AND index_resumable_operations.object_id = indexes.object_id AND index_resumable_operations.index_id = indexes.index_id AND (index_resumable_operations.partition_number = partitions.partition_number OR index_resumable_operations.partition_number IS NULL)) THEN 1 ELSE 0 END' ELSE '0' END + ' AS ResumableIndexOperation'
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
						IF @PartitionLevel = 'Y'
						BEGIN
						SET @CurrentCommand = @CurrentCommand + ' LEFT OUTER JOIN sys.partitions partitions ON indexes.[object_id] = partitions.[object_id] AND indexes.index_id = partitions.index_id'
							+ ' LEFT OUTER JOIN (SELECT partitions.[object_id], partitions.index_id, COUNT(DISTINCT partitions.partition_number) AS partition_count FROM sys.partitions partitions GROUP BY partitions.[object_id], partitions.index_id) IndexPartitions ON partitions.[object_id] = IndexPartitions.[object_id] AND partitions.[index_id] = IndexPartitions.[index_id]'
						END

						SET @CurrentCommand = @CurrentCommand + ' WHERE objects.[type] IN(''U'',''V'')'
																+ ' AND objects.is_ms_shipped = 0'
																+ ' AND indexes.[type] IN(1,2,3,4,5,6,7)'
																+ ' AND indexes.is_disabled = 0 AND indexes.is_hypothetical = 0';
					END

					SET @CurrentCommand = @CurrentCommand + ') IndexesStatistics';

					INSERT INTO dbo.IndexReorganizeTask (ID, DatabaseName, SchemaID, SchemaName, ObjectID, ObjectName, ObjectType, IsMemoryOptimized, IndexID, IndexName, IndexType, AllowPageLocks, OnReadOnlyFileGroup, ResumableIndexOperation, PartitionID, PartitionNumber, PartitionCount, [Order], Selected, Completed)
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
						FROM dbo.IndexReorganizeTask tmpIndexesStatistics
						WHERE DatabaseName = @CurrentDatabaseName;
					END
					ELSE
					BEGIN
						UPDATE tmpIndexesStatistics
						SET tmpIndexesStatistics.Selected = SelectedIndexes.Selected
						FROM dbo.IndexReorganizeTask tmpIndexesStatistics
						INNER JOIN #SelectedIndexes SelectedIndexes
						ON @CurrentDatabaseName LIKE REPLACE(SelectedIndexes.DatabaseName,'_','[_]') AND tmpIndexesStatistics.SchemaName LIKE REPLACE(SelectedIndexes.SchemaName,'_','[_]') AND tmpIndexesStatistics.ObjectName LIKE REPLACE(SelectedIndexes.ObjectName,'_','[_]') AND tmpIndexesStatistics.IndexName LIKE REPLACE(SelectedIndexes.IndexName,'_','[_]')
						WHERE tmpIndexesStatistics.DatabaseName = @CurrentDatabaseName AND SelectedIndexes.Selected = 1;

						UPDATE tmpIndexesStatistics
						SET tmpIndexesStatistics.Selected = SelectedIndexes.Selected
						FROM dbo.IndexReorganizeTask tmpIndexesStatistics
						INNER JOIN #SelectedIndexes SelectedIndexes
						ON @CurrentDatabaseName LIKE REPLACE(SelectedIndexes.DatabaseName,'_','[_]') AND tmpIndexesStatistics.SchemaName LIKE REPLACE(SelectedIndexes.SchemaName,'_','[_]') AND tmpIndexesStatistics.ObjectName LIKE REPLACE(SelectedIndexes.ObjectName,'_','[_]') AND tmpIndexesStatistics.IndexName LIKE REPLACE(SelectedIndexes.IndexName,'_','[_]')
						WHERE tmpIndexesStatistics.DatabaseName = @CurrentDatabaseName AND SelectedIndexes.Selected = 0;

						UPDATE tmpIndexesStatistics
						SET tmpIndexesStatistics.StartPosition = SelectedIndexes2.StartPosition
						FROM dbo.IndexReorganizeTask tmpIndexesStatistics
						INNER JOIN (SELECT tmpIndexesStatistics.SchemaName, tmpIndexesStatistics.ObjectName, tmpIndexesStatistics.IndexName, MIN(SelectedIndexes.StartPosition) AS StartPosition
									FROM dbo.IndexReorganizeTask tmpIndexesStatistics
									INNER JOIN #SelectedIndexes SelectedIndexes
									ON @CurrentDatabaseName LIKE REPLACE(SelectedIndexes.DatabaseName,'_','[_]') AND tmpIndexesStatistics.SchemaName LIKE REPLACE(SelectedIndexes.SchemaName,'_','[_]') AND tmpIndexesStatistics.ObjectName LIKE REPLACE(SelectedIndexes.ObjectName,'_','[_]') AND tmpIndexesStatistics.IndexName LIKE REPLACE(SelectedIndexes.IndexName,'_','[_]')
									WHERE SelectedIndexes.Selected = 1
									GROUP BY tmpIndexesStatistics.SchemaName, tmpIndexesStatistics.ObjectName, tmpIndexesStatistics.IndexName) SelectedIndexes2
						ON tmpIndexesStatistics.SchemaName = SelectedIndexes2.SchemaName
						AND tmpIndexesStatistics.ObjectName = SelectedIndexes2.ObjectName
						AND (tmpIndexesStatistics.IndexName = SelectedIndexes2.IndexName OR tmpIndexesStatistics.IndexName IS NULL)
						WHERE tmpIndexesStatistics.DatabaseName = @CurrentDatabaseName;
					END;

					WITH tmpIndexesStatistics AS (
					SELECT SchemaName, ObjectName, [Order], ROW_NUMBER() OVER (ORDER BY StartPosition ASC, SchemaName ASC, ObjectName ASC, CASE WHEN IndexType IS NULL THEN 1 ELSE 0 END ASC, IndexType ASC, IndexName ASC, PartitionNumber ASC) AS RowNumber
					FROM dbo.IndexReorganizeTask tmpIndexesStatistics
					WHERE tmpIndexesStatistics.DatabaseName = @CurrentDatabaseName AND Selected = 1
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
			AND NOT EXISTS (SELECT * FROM dbo.IndexReorganizeTask WHERE SchemaName = SelectedIndexes.SchemaName AND ObjectName = SelectedIndexes.ObjectName);
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
			AND NOT EXISTS (SELECT * FROM dbo.IndexReorganizeTask WHERE SchemaName = SelectedIndexes.SchemaName AND ObjectName = SelectedIndexes.ObjectName AND IndexName = SelectedIndexes.IndexName);
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
							 @CurrentAllowPageLocks = AllowPageLocks,
							 @CurrentIsMemoryOptimized = IsMemoryOptimized,
							 @CurrentIndexID = IndexID,
							 @CurrentIndexName = IndexName,
							 @CurrentIndexType = IndexType,
							 @CurrentOnReadOnlyFileGroup = OnReadOnlyFileGroup,
							 @CurrentResumableIndexOperation = ResumableIndexOperation,
							 @CurrentPartitionID = PartitionID,
							 @CurrentPartitionNumber = PartitionNumber,
							 @CurrentPartitionCount = PartitionCount
				FROM dbo.IndexReorganizeTask
				WHERE DatabaseName = @CurrentDatabaseName
				AND Selected = 1
				AND Completed = 0
				ORDER BY [Order] ASC;

				IF @@ROWCOUNT = 0
				BEGIN
					BREAK;
				END

				-- Is the index a partition?
				IF @CurrentPartitionNumber IS NULL OR @CurrentPartitionCount = 1 BEGIN SET @CurrentIsPartition = 0 END ELSE BEGIN SET @CurrentIsPartition = 1 END

				-- Does the index exist?
				IF @CurrentIndexID IS NOT NULL AND EXISTS(SELECT * FROM #ActionsPreferred)
				BEGIN
				  SET @CurrentCommand = ''

				  IF @LockTimeout IS NOT NULL SET @CurrentCommand = 'SET LOCK_TIMEOUT ' + CAST(@LockTimeout * 1000 AS nvarchar) + '; '

				  IF @CurrentIsPartition = 0 SET @CurrentCommand += 'IF EXISTS(SELECT * FROM sys.indexes indexes INNER JOIN sys.objects objects ON indexes.[object_id] = objects.[object_id] INNER JOIN sys.schemas schemas ON objects.[schema_id] = schemas.[schema_id] WHERE objects.[type] IN(''U'',''V'') AND indexes.[type] IN(1,2,3,4,5,6,7) AND indexes.is_disabled = 0 AND indexes.is_hypothetical = 0 AND schemas.[schema_id] = @ParamSchemaID AND schemas.[name] = @ParamSchemaName AND objects.[object_id] = @ParamObjectID AND objects.[name] = @ParamObjectName AND objects.[type] = @ParamObjectType AND indexes.index_id = @ParamIndexID AND indexes.[name] = @ParamIndexName AND indexes.[type] = @ParamIndexType) BEGIN SET @ParamIndexExists = 1 END'
				  IF @CurrentIsPartition = 1 SET @CurrentCommand += 'IF EXISTS(SELECT * FROM sys.indexes indexes INNER JOIN sys.objects objects ON indexes.[object_id] = objects.[object_id] INNER JOIN sys.schemas schemas ON objects.[schema_id] = schemas.[schema_id] INNER JOIN sys.partitions partitions ON indexes.[object_id] = partitions.[object_id] AND indexes.index_id = partitions.index_id WHERE objects.[type] IN(''U'',''V'') AND indexes.[type] IN(1,2,3,4,5,6,7) AND indexes.is_disabled = 0 AND indexes.is_hypothetical = 0 AND schemas.[schema_id] = @ParamSchemaID AND schemas.[name] = @ParamSchemaName AND objects.[object_id] = @ParamObjectID AND objects.[name] = @ParamObjectName AND objects.[type] = @ParamObjectType AND indexes.index_id = @ParamIndexID AND indexes.[name] = @ParamIndexName AND indexes.[type] = @ParamIndexType AND partitions.partition_id = @ParamPartitionID AND partitions.partition_number = @ParamPartitionNumber) BEGIN SET @ParamIndexExists = 1 END'

				  BEGIN TRY
					EXECUTE @CurrentDatabase_sp_executesql @stmt = @CurrentCommand, @params = N'@ParamSchemaID int, @ParamSchemaName sysname, @ParamObjectID int, @ParamObjectName sysname, @ParamObjectType sysname, @ParamIndexID int, @ParamIndexName sysname, @ParamIndexType int, @ParamPartitionID bigint, @ParamPartitionNumber int, @ParamIndexExists bit OUTPUT', @ParamSchemaID = @CurrentSchemaID, @ParamSchemaName = @CurrentSchemaName, @ParamObjectID = @CurrentObjectID, @ParamObjectName = @CurrentObjectName, @ParamObjectType = @CurrentObjectType, @ParamIndexID = @CurrentIndexID, @ParamIndexName = @CurrentIndexName, @ParamIndexType = @CurrentIndexType, @ParamPartitionID = @CurrentPartitionID, @ParamPartitionNumber = @CurrentPartitionNumber, @ParamIndexExists = @CurrentIndexExists OUTPUT

					IF @CurrentIndexExists IS NULL
					BEGIN
					  SET @CurrentIndexExists = 0
					  GOTO NoAction
					END
				  END TRY
				  BEGIN CATCH
					SET @ErrorMessage = 'Msg ' + CAST(ERROR_NUMBER() AS nvarchar) + ', ' + ISNULL(ERROR_MESSAGE(),'') + CASE WHEN ERROR_NUMBER() = 1222 THEN ' The index ' + QUOTENAME(@CurrentIndexName) + ' on the object ' + QUOTENAME(@CurrentDatabaseName) + '.' + QUOTENAME(@CurrentSchemaName) + '.' + QUOTENAME(@CurrentObjectName) + ' is locked. It could not be checked if the index exists.' ELSE '' END
					SET @Severity = CASE WHEN ERROR_NUMBER() IN(1205,1222) THEN @LockMessageSeverity ELSE 16 END
					RAISERROR('%s',@Severity,1,@ErrorMessage) WITH NOWAIT
					RAISERROR(@EmptyLine,10,1) WITH NOWAIT

					IF NOT (ERROR_NUMBER() IN(1205,1222) AND @LockMessageSeverity = 10)
					BEGIN
					  SET @ReturnCode = ERROR_NUMBER()
					END

					GOTO NoAction
				  END CATCH
				END

				-- Is the index fragmented?
				IF @CurrentIndexID IS NOT NULL
				AND @CurrentOnReadOnlyFileGroup = 0
				AND EXISTS(SELECT * FROM #ActionsPreferred)
				AND (EXISTS(SELECT [Priority], [Action], COUNT(*) FROM #ActionsPreferred GROUP BY [Priority], [Action] HAVING COUNT(*) <> 3) OR @MinNumberOfPages > 0 OR @MaxNumberOfPages IS NOT NULL)
				BEGIN
				  SET @CurrentCommand = ''

				  IF @LockTimeout IS NOT NULL SET @CurrentCommand = 'SET LOCK_TIMEOUT ' + CAST(@LockTimeout * 1000 AS nvarchar) + '; '

				  SET @CurrentCommand += 'SELECT @ParamFragmentationLevel = MAX(avg_fragmentation_in_percent), @ParamPageCount = SUM(page_count) FROM sys.dm_db_index_physical_stats(DB_ID(@ParamDatabaseName), @ParamObjectID, @ParamIndexID, @ParamPartitionNumber, ''LIMITED'') WHERE alloc_unit_type_desc = ''IN_ROW_DATA'' AND index_level = 0'

				  BEGIN TRY
					EXECUTE sp_executesql @stmt = @CurrentCommand, @params = N'@ParamDatabaseName nvarchar(max), @ParamObjectID int, @ParamIndexID int, @ParamPartitionNumber int, @ParamFragmentationLevel float OUTPUT, @ParamPageCount bigint OUTPUT', @ParamDatabaseName = @CurrentDatabaseName, @ParamObjectID = @CurrentObjectID, @ParamIndexID = @CurrentIndexID, @ParamPartitionNumber = @CurrentPartitionNumber, @ParamFragmentationLevel = @CurrentFragmentationLevel OUTPUT, @ParamPageCount = @CurrentPageCount OUTPUT
				  END TRY
				  BEGIN CATCH
					SET @ErrorMessage = 'Msg ' + CAST(ERROR_NUMBER() AS nvarchar) + ', ' + ISNULL(ERROR_MESSAGE(),'') + CASE WHEN ERROR_NUMBER() = 1222 THEN ' The index ' + QUOTENAME(@CurrentIndexName) + ' on the object ' + QUOTENAME(@CurrentDatabaseName) + '.' + QUOTENAME(@CurrentSchemaName) + '.' + QUOTENAME(@CurrentObjectName) + ' is locked. The page_count and avg_fragmentation_in_percent could not be checked.' ELSE '' END
					SET @Severity = CASE WHEN ERROR_NUMBER() IN(1205,1222) THEN @LockMessageSeverity ELSE 16 END
					RAISERROR('%s',@Severity,1,@ErrorMessage) WITH NOWAIT
					RAISERROR(@EmptyLine,10,1) WITH NOWAIT

					IF NOT (ERROR_NUMBER() IN(1205,1222) AND @LockMessageSeverity = 10)
					BEGIN
					  SET @ReturnCode = ERROR_NUMBER()
					END

					GOTO NoAction
				  END CATCH
				END

				-- Select fragmentation group
				IF @CurrentIndexID IS NOT NULL AND @CurrentOnReadOnlyFileGroup = 0 AND EXISTS(SELECT * FROM #ActionsPreferred)
				BEGIN
				  SET @CurrentFragmentationGroup = CASE
				  WHEN @CurrentFragmentationLevel >= @FragmentationLevel2 THEN 'High'
				  WHEN @CurrentFragmentationLevel >= @FragmentationLevel1 AND @CurrentFragmentationLevel < @FragmentationLevel2 THEN 'Medium'
				  WHEN @CurrentFragmentationLevel < @FragmentationLevel1 THEN 'Low'
				  END
				END

				-- Which actions are allowed?
				IF @CurrentIndexID IS NOT NULL AND EXISTS(SELECT * FROM #ActionsPreferred)
				BEGIN
				  IF @CurrentOnReadOnlyFileGroup = 0 AND @CurrentIndexType IN (1,2,3,4,5) AND (@CurrentIsMemoryOptimized = 0 OR @CurrentIsMemoryOptimized IS NULL) AND (@CurrentAllowPageLocks = 1 OR @CurrentIndexType = 5)
				  BEGIN
					INSERT INTO #CurrentActionsAllowed ([Action])
					VALUES ('INDEX_REORGANIZE')
				  END
				END

				-- Decide action
				IF @CurrentIndexID IS NOT NULL
				AND EXISTS(SELECT * FROM #ActionsPreferred)
				AND (@CurrentPageCount >= @MinNumberOfPages OR @MinNumberOfPages = 0)
				AND (@CurrentPageCount <= @MaxNumberOfPages OR @MaxNumberOfPages IS NULL)
				AND @CurrentResumableIndexOperation = 0
				BEGIN
				  IF EXISTS(SELECT [Priority], [Action], COUNT(*) FROM #ActionsPreferred GROUP BY [Priority], [Action] HAVING COUNT(*) <> 3)
				  BEGIN
					SELECT @CurrentAction = [Action]
					FROM #ActionsPreferred
					WHERE FragmentationGroup = @CurrentFragmentationGroup
					AND [Priority] = (SELECT MIN([Priority])
									  FROM #ActionsPreferred
									  WHERE FragmentationGroup = @CurrentFragmentationGroup
									  AND [Action] IN (SELECT [Action] FROM #CurrentActionsAllowed))
				  END
				  ELSE
				  BEGIN
					SELECT @CurrentAction = [Action]
					FROM #ActionsPreferred
					WHERE [Priority] = (SELECT MIN([Priority])
										FROM #ActionsPreferred
										WHERE [Action] IN (SELECT [Action] FROM #CurrentActionsAllowed))
				  END
				END

				-- Create index comment
				IF @CurrentIndexID IS NOT NULL
				BEGIN
				  SET @CurrentComment = 'ObjectType: ' + CASE WHEN @CurrentObjectType = 'U' THEN 'Table' WHEN @CurrentObjectType = 'V' THEN 'View' ELSE 'N/A' END + ', '
				  SET @CurrentComment += 'IndexType: ' + CASE WHEN @CurrentIndexType = 1 THEN 'Clustered' WHEN @CurrentIndexType = 2 THEN 'NonClustered' WHEN @CurrentIndexType = 3 THEN 'XML' WHEN @CurrentIndexType = 4 THEN 'Spatial' WHEN @CurrentIndexType = 5 THEN 'Clustered Columnstore' WHEN @CurrentIndexType = 6 THEN 'NonClustered Columnstore' WHEN @CurrentIndexType = 7 THEN 'NonClustered Hash' ELSE 'N/A' END + ', '
				  SET @CurrentComment += 'AllowPageLocks: ' + CASE WHEN @CurrentAllowPageLocks = 1 THEN 'Yes' WHEN @CurrentAllowPageLocks = 0 THEN 'No' ELSE 'N/A' END + ', '
				  SET @CurrentComment += 'PageCount: ' + ISNULL(CAST(@CurrentPageCount AS nvarchar),'N/A') + ', '
				  SET @CurrentComment += 'Fragmentation: ' + ISNULL(CAST(@CurrentFragmentationLevel AS nvarchar),'N/A')
				END

				IF @CurrentIndexID IS NOT NULL AND (@CurrentPageCount IS NOT NULL OR @CurrentFragmentationLevel IS NOT NULL)
				BEGIN
				SET @CurrentExtendedInfo = (SELECT *
											FROM (SELECT CAST(@CurrentPageCount AS nvarchar) AS [PageCount],
														 CAST(@CurrentFragmentationLevel AS nvarchar) AS Fragmentation
											) ExtendedInfo FOR XML RAW('ExtendedInfo'), ELEMENTS)
				END

				IF @CurrentIndexID IS NOT NULL AND @CurrentAction IS NOT NULL AND (SYSDATETIME() < DATEADD(SECOND,@TimeLimit,@StartTime) OR @TimeLimit IS NULL)
				BEGIN
				  SET @CurrentDatabaseContext = @CurrentDatabaseName

				  SET @CurrentCommandType = 'ALTER_INDEX'

				  SET @CurrentCommand = ''
				  IF @LockTimeout IS NOT NULL SET @CurrentCommand = 'SET LOCK_TIMEOUT ' + CAST(@LockTimeout * 1000 AS nvarchar) + '; '
				  SET @CurrentCommand += 'ALTER INDEX ' + QUOTENAME(@CurrentIndexName) + ' ON ' + QUOTENAME(@CurrentSchemaName) + '.' + QUOTENAME(@CurrentObjectName)
				  IF @CurrentAction IN('INDEX_REORGANIZE') AND @CurrentResumableIndexOperation = 0 SET @CurrentCommand += ' REORGANIZE'
				  IF @CurrentIsPartition = 1 AND @CurrentResumableIndexOperation = 0 SET @CurrentCommand += ' PARTITION = ' + CAST(@CurrentPartitionNumber AS nvarchar)
				  IF @CurrentAction IN('INDEX_REORGANIZE') AND @LOBCompaction = 'Y'
				  BEGIN
					INSERT INTO #CurrentAlterIndexWithClauseArguments (Argument)
					SELECT 'LOB_COMPACTION = ON'
				  END

				  IF @CurrentAction IN('INDEX_REORGANIZE') AND @LOBCompaction = 'N'
				  BEGIN
					INSERT INTO #CurrentAlterIndexWithClauseArguments (Argument)
					SELECT 'LOB_COMPACTION = OFF'
				  END

				  IF EXISTS (SELECT * FROM #CurrentAlterIndexWithClauseArguments)
				  BEGIN
					SET @CurrentAlterIndexWithClause = ' WITH ('

					WHILE (1 = 1)
					BEGIN
						SELECT TOP 1 @CurrentAlterIndexArgumentID = ID,
									@CurrentAlterIndexArgument = Argument
						FROM #CurrentAlterIndexWithClauseArguments
						WHERE Added = 0
						ORDER BY ID ASC

						IF @@ROWCOUNT = 0
						BEGIN
						BREAK
						END

						SET @CurrentAlterIndexWithClause += @CurrentAlterIndexArgument + ', '

						UPDATE #CurrentAlterIndexWithClauseArguments
						SET Added = 1
						WHERE [ID] = @CurrentAlterIndexArgumentID
					END

					SET @CurrentAlterIndexWithClause = RTRIM(@CurrentAlterIndexWithClause)

					SET @CurrentAlterIndexWithClause = LEFT(@CurrentAlterIndexWithClause,LEN(@CurrentAlterIndexWithClause) - 1)

					SET @CurrentAlterIndexWithClause = @CurrentAlterIndexWithClause + ')'
				  END

				  IF @CurrentAlterIndexWithClause IS NOT NULL SET @CurrentCommand += @CurrentAlterIndexWithClause;

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
						INSERT INTO dbo.IndexReorganizeLog (DatabaseName, SchemaName, ObjectName, ObjectType, IndexName, IndexType, PartitionNumber, ExtendedInfo, CommandType, Command, StartTime)
						OUTPUT inserted.ID INTO @UniqueID
						VALUES (@CurrentDatabaseName, @CurrentSchemaName, @CurrentObjectName, @CurrentObjectType, @CurrentIndexName, @CurrentIndexType, @CurrentPartitionNumber, @CurrentExtendedInfo, @CurrentCommandType, @CurrentCommand, @StartTime);
						
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
						UPDATE dbo.IndexReorganizeLog
						SET EndTime = @EndTime,
							ErrorNumber = @Error,
							ErrorMessage = @ErrorMessage
						WHERE ID = @CurrentLogID;
					END

					IF @Error <> 0 SET @CurrentCommandOutput = @Error;
					IF @CurrentCommandOutput <> 0 SET @ReturnCode = @CurrentCommandOutput;
				END

			NoAction:

			-- Update that the index is completed
			UPDATE dbo.IndexReorganizeTask
			SET Completed = 1
			WHERE Selected = 1
			AND Completed = 0
			AND [Order] = @CurrentIxOrder
			AND ID = @CurrentIxID;

			-- Clear variables
			SET @CurrentDatabaseContext = NULL
			SET @CurrentCommand = NULL
			SET @CurrentCommandOutput = NULL
			SET @CurrentCommandType = NULL
			SET @CurrentComment = NULL
			SET @CurrentExtendedInfo = NULL
			SET @CurrentIxID = NULL
			SET @CurrentIxOrder = NULL
			SET @CurrentSchemaID = NULL
			SET @CurrentSchemaName = NULL
			SET @CurrentObjectID = NULL
			SET @CurrentObjectName = NULL
			SET @CurrentObjectType = NULL
			SET @CurrentIsMemoryOptimized = NULL
			SET @CurrentIndexID = NULL
			SET @CurrentIndexName = NULL
			SET @CurrentIndexType = NULL
			SET @CurrentPartitionID = NULL
			SET @CurrentPartitionNumber = NULL
			SET @CurrentPartitionCount = NULL
			SET @CurrentIsPartition = NULL
			SET @CurrentIndexExists = NULL
			SET @CurrentAllowPageLocks = NULL
			SET @CurrentResumableIndexOperation = NULL
			SET @CurrentFragmentationLevel = NULL
			SET @CurrentPageCount = NULL
			SET @CurrentFragmentationGroup = NULL
			SET @CurrentAction = NULL
			SET @CurrentAlterIndexArgumentID = NULL
			SET @CurrentAlterIndexArgument = NULL
			SET @CurrentAlterIndexWithClause = NULL

			DELETE FROM #CurrentActionsAllowed
			DELETE FROM #CurrentAlterIndexWithClauseArguments

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

	-- Remove unselected indexes
	DELETE FROM dbo.IndexReorganizeTask
	WHERE DatabaseName = @CurrentDatabaseName
	AND Selected = 0
	AND Completed = 0;

	-- Clear variables
	SET @CurrentDBID = NULL
	SET @CurrentDatabaseName = NULL
	SET @CurrentDatabase_sp_executesql = NULL
	SET @CurrentUserAccess = NULL
	SET @CurrentIsReadOnly = NULL
	SET @CurrentDatabaseState = NULL
	SET @CurrentInStandby = NULL
	SET @CurrentRecoveryModel = NULL
	SET @CurrentIsDatabaseAccessible = NULL
	SET @CurrentCommand = NULL
  END

	IF NOT EXISTS (SELECT 1 FROM dbo.IndexReorganizeTask WHERE Completed = 0)
	BEGIN
		TRUNCATE TABLE dbo.IndexReorganizeTask;
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
    RETURN @ReturnCode
  END
END

GO


