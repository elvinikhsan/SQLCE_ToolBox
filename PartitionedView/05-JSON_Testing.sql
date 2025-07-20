ALTER TABLE dbo.Employees_2024
ADD JSONData NVARCHAR(MAX) NULL;
GO
ALTER TABLE dbo.Employees_2023
ADD JSONData NVARCHAR(MAX) NULL;
GO
ALTER TABLE dbo.Employees_2022
ADD JSONData NVARCHAR(MAX) NULL;
GO
ALTER VIEW [dbo].[VW_Employee]
AS
SELECT EmployeeId, EmployeeName, HireDate, EmploymentYear, JSONData FROM Employees_2024
UNION ALL
SELECT EmployeeId, EmployeeName, HireDate, EmploymentYear, JSONData FROM Employees_2023
UNION ALL
SELECT EmployeeId, EmployeeName, HireDate, EmploymentYear, JSONData FROM Employees_2022
GO
UPDATE a
SET a.JSONData = (SELECT b.* FROM dbo.Employees_2024 b WHERE b.EmployeeId = a.EmployeeId FOR JSON AUTO)
FROM dbo.Employees_2024 a;
GO
UPDATE a
SET a.JSONData = (SELECT b.* FROM dbo.Employees_2023 b WHERE b.EmployeeId = a.EmployeeId FOR JSON AUTO)
FROM dbo.Employees_2023 a;
GO
UPDATE a
SET a.JSONData = (SELECT b.* FROM dbo.Employees_2022 b WHERE b.EmployeeId = a.EmployeeId FOR JSON AUTO)
FROM dbo.Employees_2022 a;
GO
SELECT *, JSON_VALUE(JSONData,'$[0].EmployeeName')
FROM dbo.VW_Employee
WHERE EmployeeId = 111
GO
-- JSONData = JSON_MODIFY(JSONData,'$[0].EmployeeName','Superboy')
GO
UPDATE a
SET a.EmployeeName = (SELECT JSON_VALUE(b.JSONData,'$[0].EmployeeName') FROM dbo.VW_Employee b WHERE a.EmployeeId = b.EmployeeId)
FROM dbo.VW_Employee a
WHERE a.EmployeeId = 111;
GO
UPDATE a
SET a.JSONData = JSON_MODIFY(a.JSONData,'$[0].EmployeeName','Superman')
FROM dbo.VW_Employee a
WHERE a.EmployeeId = 111;
GO