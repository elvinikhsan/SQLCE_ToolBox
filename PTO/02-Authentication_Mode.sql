SELECT @@SERVERNAME, CASE SERVERPROPERTY('IsIntegratedSecurityOnly')   
WHEN 1 THEN 'Windows Authentication'   
WHEN 0 THEN 'Windows and SQL Server Authentication'   
END as [Authentication Mode]