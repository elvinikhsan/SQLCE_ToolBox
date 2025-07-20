CREATE DATABASE PartitionedDemo;
GO

-- Creating Employee tables for years 2024, 2023, and 2022
USE PartitionedDemo;
GO

-- Employee year 2024
CREATE TABLE Employees_2024 (
    EmployeeId INT NOT NULL,
    EmployeeName VARCHAR(100) NOT NULL,
    HireDate DATETIME NULL,
    EmploymentYear INT NOT NULL,
    CONSTRAINT PK_Employee_2024 PRIMARY KEY (EmployeeId, EmploymentYear)
);
GO

-- Employee year 2023
CREATE TABLE Employees_2023 (
    EmployeeId INT NOT NULL,
    EmployeeName VARCHAR(100) NOT NULL,
    HireDate DATETIME NULL,
    EmploymentYear INT NOT NULL,
    CONSTRAINT PK_Employee_2023 PRIMARY KEY (EmployeeId, EmploymentYear)
);
GO

-- Employee year 2022
CREATE TABLE Employees_2022 (
    EmployeeId INT NOT NULL,
    EmployeeName VARCHAR(100) NOT NULL,
    HireDate DATETIME NULL,
    EmploymentYear INT NOT NULL,
    CONSTRAINT PK_Employee_2022 PRIMARY KEY (EmployeeId, EmploymentYear)
);
GO
USE PartitionedDemo
GO
-- CHECK CONSTRAINTS FOR PARTITIONED VIEW
ALTER TABLE Employees_2022 ADD CONSTRAINT CK_Employee_2022 CHECK (EmploymentYear = 2022);

ALTER TABLE Employees_2023 ADD CONSTRAINT CK_Employee_2023 CHECK (EmploymentYear = 2023);

ALTER TABLE Employees_2024 ADD CONSTRAINT CK_Employee_2024 CHECK (EmploymentYear = 2024);
GO