USE PartitionedDemo
GO
CREATE VIEW VW_Employee
AS
SELECT EmployeeId, EmployeeName, HireDate, EmploymentYear FROM Employees_2024
UNION ALL
SELECT EmployeeId, EmployeeName, HireDate, EmploymentYear FROM Employees_2023
UNION ALL
SELECT EmployeeId, EmployeeName, HireDate, EmploymentYear FROM Employees_2022
GO