/*** LEDGER Demo ***/
-- Alternatively you can create a full LEDGER database:
-- CREATE DATABASE <db_name> WITH LEDGER = ON;
-- All tables in this database will be enabled automatically for updateable ledger table
-- The following is to demo ledger table in a standard database
-- Create a new schema and table called [Account].[Balance].
-- Creating updatable ledger tables requires the ENABLE LEDGER permission.

CREATE SCHEMA [Account];
GO  
CREATE TABLE [Account].[Balance]
([CustomerID] INT NOT NULL PRIMARY KEY CLUSTERED,
    [LastName] VARCHAR (50) NOT NULL,
    [FirstName] VARCHAR (50) NOT NULL,
    [Balance] DECIMAL (10,2) NOT NULL)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = [Account].[BalanceHistory]),
 LEDGER = ON);

--When your updatable ledger table is created, the corresponding history table and ledger view are also created. Run the following T-SQL commands to see the new table and the new view.

SELECT ts.[name] + '.' + t.[name] AS [ledger_table_name]
, hs.[name] + '.' + h.[name] AS [history_table_name]
, vs.[name] + '.' + v.[name] AS [ledger_view_name]
FROM sys.tables AS t
JOIN sys.tables AS h ON (h.[object_id] = t.[history_table_id])
JOIN sys.views v ON (v.[object_id] = t.[ledger_view_id])
JOIN sys.schemas ts ON (ts.[schema_id] = t.[schema_id])
JOIN sys.schemas hs ON (hs.[schema_id] = h.[schema_id])
JOIN sys.schemas vs ON (vs.[schema_id] = v.[schema_id])
WHERE t.[name] = 'Balance';

-- Insert the name Nick Jones as a new customer with an opening balance of $50.

INSERT INTO [Account].[Balance]
VALUES (1, 'Jones', 'Nick', 50);

-- Insert the names John Smith, Joe Smith, and Mary Michaels as new customers with opening balances of $500, $30, and $200, respectively.

INSERT INTO [Account].[Balance]
VALUES(2, 'Smith', 'John', 500),
(3, 'Smith', 'Joe', 30),
(4, 'Michaels', 'Mary', 200);

--View the [Account].[Balance] updatable ledger table, and specify the GENERATED ALWAY columns added to the table.

SELECT [CustomerID]
   ,[LastName]
   ,[FirstName]
   ,[Balance]
   ,[ledger_start_transaction_id]
   ,[ledger_end_transaction_id]
   ,[ledger_start_sequence_number]
   ,[ledger_end_sequence_number]
 FROM [Account].[Balance];

/* In the results window, you'll first see the values inserted by your T-SQL commands, along with the system metadata that's used for data lineage purposes.

The ledger_start_transaction_id column notes the unique transaction ID associated with the transaction that inserted the data. Because John, Joe, and Mary were inserted by using the same transaction, they share the same transaction ID.

The ledger_start_sequence_number column notes the order by which values were inserted by the transaction.
*/

-- Update Nick's balance from 50 to 100.

UPDATE [Account].[Balance] SET [Balance] = 100
WHERE [CustomerID] = 1;

-- View the [Account].[Balance] ledger view, along with the transaction ledger system view to identify users that made the changes.

SELECT t.[commit_time] AS [CommitTime] 
 , t.[principal_name] AS [UserName]
 , l.[CustomerID]
 , l.[LastName]
 , l.[FirstName]
 , l.[Balance]
 , l.[ledger_operation_type_desc] AS Operation
 FROM [Account].[Balance_Ledger] l
 JOIN sys.database_ledger_transactions t
 ON t.transaction_id = l.ledger_transaction_id
 ORDER BY t.commit_time DESC;

 /* Nick's account balance was successfully updated in the updatable ledger table to 100. The ledger view shows that updating the ledger table is a DELETE of the original row with 50. The balance with a corresponding INSERT of a new row with 100 shows the new balance for Nick. */

 SELECT * FROM Account.BalanceHistory

