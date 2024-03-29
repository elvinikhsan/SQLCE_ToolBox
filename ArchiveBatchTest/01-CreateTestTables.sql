USE tempdb;
GO
CREATE TABLE dbo.SourceTest
(Id INT IDENTITY(1,1)
,Content VARCHAR(10)
,CreatedDate DATETIME CONSTRAINT DF_SourceTest_CreatedDate DEFAULT GETDATE()
CONSTRAINT PK_SourceTest PRIMARY KEY CLUSTERED (Id)
);
GO
CREATE TABLE dbo.SourceTest_Temp
(Id INT IDENTITY(1,1)
,Content VARCHAR(10)
,CreatedDate DATETIME CONSTRAINT DF_SourceTest_Temp_CreatedDate DEFAULT GETDATE()
CONSTRAINT PK_SourceTest_Temp PRIMARY KEY CLUSTERED (Id)
);
GO
CREATE TABLE dbo.ArchiveTest
(Id INT 
,Content VARCHAR(10)
,CreatedDate DATETIME 
CONSTRAINT PK_ArchiveTest PRIMARY KEY CLUSTERED (Id)
);
GO