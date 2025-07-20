USE PartitionedDemo
GO

-- year 2024
INSERT INTO [dbo].[Employees_2024] ([EmployeeId], [EmployeeName], [HireDate], [EmploymentYear])
VALUES 
    (101, 'Alice Smith', '2024-02-15', 2024),
    (102, 'Bob Johnson', '2024-03-20', 2024),
    (103, 'Carol Davis', '2024-01-11', 2024),
    (104, 'Dan Harris', '2024-04-05', 2024),
    (105, 'Eve Taylor', '2024-05-30', 2024),
    (106, 'Frank White', '2024-07-12', 2024),
    (107, 'Grace Lewis', '2024-06-23', 2024),
    (108, 'Hank Clark', '2024-08-15', 2024),
    (109, 'Ivy King', '2024-09-02', 2024),
    (110, 'Jackie Scott', '2024-10-14', 2024);
GO

-- year 2023
INSERT INTO [dbo].[Employees_2023] ([EmployeeId], [EmployeeName], [HireDate], [EmploymentYear])
VALUES 
    (201, 'Charlie Brown', '2023-05-10', 2023),
    (202, 'David Lee', '2023-06-15', 2023),
    (203, 'Emma Walker', '2023-01-22', 2023),
    (204, 'George Hall', '2023-02-17', 2023),
    (205, 'Helen Allen', '2023-03-25', 2023),
    (206, 'Ian Young', '2023-04-14', 2023),
    (207, 'Jack Williams', '2023-07-03', 2023),
    (208, 'Kelly Brown', '2023-08-06', 2023),
    (209, 'Liam Clark', '2023-09-12', 2023),
    (210, 'Mona Evans', '2023-10-29', 2023);
GO

-- year 2022
INSERT INTO [dbo].[Employees_2022] ([EmployeeId], [EmployeeName], [HireDate], [EmploymentYear])
VALUES 
    (301, 'Eve Williams', '2022-08-25', 2022),
    (302, 'Frank Moore', '2022-09-30', 2022),
    (303, 'Grace Turner', '2022-03-11', 2022),
    (304, 'Henry Moore', '2022-01-08', 2022),
    (305, 'Ivy Scott', '2022-04-14', 2022),
    (306, 'John Adams', '2022-05-06', 2022),
    (307, 'Kathy Miller', '2022-06-19', 2022),
    (308, 'Leo Carter', '2022-07-27', 2022),
    (309, 'Maya Jackson', '2022-10-03', 2022),
    (310, 'Nina Lewis', '2022-11-15', 2022);
GO