DECLARE @sql NVARCHAR(MAX);
DECLARE @database_name SYSNAME;

-- Create a temporary table to store the results
IF OBJECT_ID('tempdb..#DatabaseScopedConfigurations') IS NOT NULL
DROP TABLE #DatabaseScopedConfigurations;

CREATE TABLE #DatabaseScopedConfigurations (
    DatabaseName SYSNAME,
    configuration_id INT,
    name NVARCHAR(60),
    value SQL_VARIANT,
    value_for_secondary SQL_VARIANT,
    is_value_default BIT
);

-- Cursor to iterate through each user database
DECLARE db_cursor CURSOR FOR
SELECT name
FROM sys.databases
WHERE state = 0 -- ONLINE
AND is_read_only = 0 -- Not read-only
AND database_id > 4; -- Exclude system databases (master, model, msdb, tempdb)

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @database_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'USE [' + @database_name + ']; ' +
               N'INSERT INTO #DatabaseScopedConfigurations (DatabaseName, configuration_id, name, value, value_for_secondary, is_value_default) ' +
               N'SELECT ''' + @database_name + ''', configuration_id, name, value, value_for_secondary, is_value_default ' +
               N'FROM sys.database_scoped_configurations;';

    EXEC sp_executesql @sql;

    FETCH NEXT FROM db_cursor INTO @database_name;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- Select all results from the temporary table
SELECT *
FROM #DatabaseScopedConfigurations
ORDER BY DatabaseName, name;