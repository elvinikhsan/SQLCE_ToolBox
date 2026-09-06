In-Memory OLTP Performance Demo
--------------------------------
This Windows Forms sample application built on .NET Framework 4.6 demonstrates the performance benefits of using SQL Server memory optimized tables and native compiled stored procedures. You can compare the performance before and after enabling In-Memory OLTP by observing the transactions/sec as well as the current CPU Usage and latches/sec.

-- Applies To: SQL Server 2014 (or higher); Azure SQL Database
-- Requires: .NET framework 4.6
-- Last Updated: 2016-12-08

The demo works with a SQL database and a client application.
When run with Azure SQL Database, the client should be run on a VM in the same region as the database.
When run with SQL Server, the client should be run on the same machine or a machine in the same network as the server.

To run the performance demo, follow these steps:
1. Create a database with the name TicketReservations
2. Run the script setup-or-reset-demo.sql to create the traditional disk-based table and interpreted T-SQL stored procedures
3. Start the application DemoWorkload.exe
4. Change the connection string in the configuration settings, if needed. By default, it points to the local default SQL Server instance with integrated authentication.
5. Start the workload by clicking the "start" button, let it run for a while using the "stop" button
   - If nothing seems to happen, maximize the window. There is a box with error messages to the right.
6. Migrate the table to memory-optimized and key stored procedure to natively compiled in one of two ways:
   I. Executing the script apply-in-memory-oltp.sql, or
   II. Using the Transaction Performance Analysis Report and memory-optimization advisor in SQL Server Management Studio to migrate the table
7. Start the workload again, and observe the performance gain. Stop the workload to conclude the demo.
8. To reset the demo, run the script setup-or-reset-demo.sql

An alternative way to run this demo leveraging Visual Studio Database Project deployment is documented here:
https://github.com/Microsoft/sql-server-samples/tree/master/samples/features/in-memory/ticket-reservations


The perf gains from In-Memory OLTP as shown by the load generation app depend on two factors:

1. Hardware
   - more cores => higher perf gain
   - slower log IO => lower perf gain
2. Configuration settings in the load generator
   - more rows per transaction => higher perf gain
   - more reads per write => lower perf gain
   - default setting is 100 rows per transaction and 1 read per write

If the performance profile after migration to In-Memory OLTP looks choppy, it is likely that log IO is the bottleneck. This can be mitigated by using delayed durability. This is enabled by running the following statement in the database: 
  ALTER DATABASE CURRENT SET DELAYED_DURABILITY = FORCED

With default settings on one machine with 24 cores and SSD for the log the app shows around performance 40X gain, and in this case the bottleneck was log IO. When deploying to Azure SQL Database, make sure to run the app in an Azure VM in the same region as the database.

If you have a beefy machine and are seeing a drop-off in transaction throughput after running the demo for a while, increase the BUCKET_COUNT in 'apply-in-memory-oltp.sql' by a factor of 10 or 100.


For any feedback on the sample, contact: sqlserversamples@microsoft.com

--------------
Source code:
https://github.com/Microsoft/sql-server-samples/tree/master/samples/features/in-memory/ticket-reservations

License:
https://github.com/Microsoft/sql-server-samples/blob/master/license.txt
