USE PartitionedDemo
GO
INSERT INTO [dbo].[VW_Employee] ([EmployeeId], [EmployeeName], [HireDate], [EmploymentYear])
VALUES (111, 'Clark Kent', '2024-06-12', 2024);

INSERT INTO [dbo].[VW_Employee] ([EmployeeId], [EmployeeName], [HireDate], [EmploymentYear])
VALUES (211, 'Mike Tyson', '2023-11-10', 2023);

INSERT INTO [dbo].[VW_Employee] ([EmployeeId], [EmployeeName], [HireDate], [EmploymentYear])
VALUES (311, 'Joe Sad', '2022-01-04', 2022);