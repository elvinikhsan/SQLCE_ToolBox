USE [PosEFDb]
GO
CREATE TABLE [dbo].[Sales_StoreA](
	[Id] [int] NOT NULL,
	[StoreId] [int] NOT NULL,
	[ProductId] [int] NOT NULL,
	[ProductName] [varchar](50) NOT NULL,
	[Qty] [decimal](18, 3) NOT NULL,
	[Price] [decimal](18, 3) NOT NULL,
	[Amount] [decimal](18, 3) NOT NULL,
	[TrxDate] [datetime] NOT NULL,
	[CreatedBy] [varchar](50) NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	[ModifiedBy] [varchar](50) NULL,
	[ModifiedDate] [datetime] NULL,
 CONSTRAINT [PK_Sales_StoreA] PRIMARY KEY CLUSTERED 
(
	[Id] ASC, [StoreId] ASC
));
GO
CREATE TABLE [dbo].[Sales_StoreB](
	[Id] [int] NOT NULL,
	[StoreId] [int] NOT NULL,
	[ProductId] [int] NOT NULL,
	[ProductName] [varchar](50) NOT NULL,
	[Qty] [decimal](18, 3) NOT NULL,
	[Price] [decimal](18, 3) NOT NULL,
	[Amount] [decimal](18, 3) NOT NULL,
	[TrxDate] [datetime] NOT NULL,
	[CreatedBy] [varchar](50) NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	[ModifiedBy] [varchar](50) NULL,
	[ModifiedDate] [datetime] NULL,
 CONSTRAINT [PK_Sales_StoreB] PRIMARY KEY CLUSTERED 
(
	[Id] ASC, [StoreId] ASC
));
GO
ALTER TABLE [dbo].[Sales_StoreA] ADD  DEFAULT ('System') FOR [CreatedBy]
GO
ALTER TABLE [dbo].[Sales_StoreA] ADD  DEFAULT (getdate()) FOR [CreatedDate]
GO
ALTER TABLE [dbo].[Sales_StoreB] ADD  DEFAULT ('System') FOR [CreatedBy]
GO
ALTER TABLE [dbo].[Sales_StoreB] ADD  DEFAULT (getdate()) FOR [CreatedDate]
GO
-- CHECK CONSTRAINTS FOR PARTITIONED VIEW
ALTER TABLE [Sales_StoreA] ADD CONSTRAINT CK_STOREA CHECK (StoreId = 1);
GO
ALTER TABLE [Sales_StoreB] ADD CONSTRAINT CK_STOREB CHECK (StoreId = 2);
GO
-- IMPORT DATA FROM dbo.Sales
INSERT INTO dbo.Sales_StoreA
SELECT [Id]
      ,[StoreId]
      ,[ProductId]
      ,[ProductName]
      ,[Qty]
      ,[Price]
      ,[Amount]
      ,[TrxDate]
      ,[CreatedBy]
      ,[CreatedDate]
      ,[ModifiedBy]
      ,[ModifiedDate]
FROM dbo.Sales
WHERE StoreId = 1;
GO
INSERT INTO dbo.Sales_StoreB
SELECT [Id]
      ,[StoreId]
      ,[ProductId]
      ,[ProductName]
      ,[Qty]
      ,[Price]
      ,[Amount]
      ,[TrxDate]
      ,[CreatedBy]
      ,[CreatedDate]
      ,[ModifiedBy]
      ,[ModifiedDate]
FROM dbo.Sales
WHERE StoreId = 2;
GO
-- CREATE PARTITIONED VIEW
CREATE VIEW VW_Sales
AS
SELECT [Id]
      ,[StoreId]
      ,[ProductId]
      ,[ProductName]
      ,[Qty]
      ,[Price]
      ,[Amount]
      ,[TrxDate]
      ,[CreatedBy]
      ,[CreatedDate]
      ,[ModifiedBy]
      ,[ModifiedDate]
FROM dbo.Sales_StoreA
UNION ALL
SELECT [Id]
      ,[StoreId]
      ,[ProductId]
      ,[ProductName]
      ,[Qty]
      ,[Price]
      ,[Amount]
      ,[TrxDate]
      ,[CreatedBy]
      ,[CreatedDate]
      ,[ModifiedBy]
      ,[ModifiedDate] 
FROM dbo.Sales_StoreB
GO