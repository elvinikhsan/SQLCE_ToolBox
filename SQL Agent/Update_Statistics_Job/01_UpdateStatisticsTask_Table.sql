USE [master]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UpdateStatisticsTask](
	[ID] [int] NOT NULL,
	[DatabaseName] SYSNAME NOT NULL,
	[SchemaID] [int] NULL,
	[SchemaName] [nvarchar](max) NULL,
	[ObjectID] [int] NULL,
	[ObjectName] [nvarchar](max) NULL,
	[ObjectType] [nvarchar](max) NULL,
	[IsMemoryOptimized] [bit] NULL,
	[IndexID] [int] NULL,
	[IndexName] [nvarchar](max) NULL,
	[IndexType] [int] NULL,
	[IsTimestamp] [bit] NULL,
	[OnReadOnlyFileGroup] [bit] NULL,
	[StatisticsID] [int] NULL,
	[StatisticsName] [nvarchar](max) NULL,
	[NoRecompute] [bit] NULL,
	[IsIncremental] [bit] NULL,
	[PartitionID] [bigint] NULL,
	[PartitionNumber] [int] NULL,
	[PartitionCount] [int] NULL,
	[StartPosition] [int] NULL,
	[Order] [int] NOT NULL,
	[Selected] [bit] NOT NULL,
	[Completed] [bit] NOT NULL,
CONSTRAINT [PK_UpdateStatisticsTask] PRIMARY KEY CLUSTERED 
(
	[DatabaseName] ASC,
	[Selected] ASC,
	[Completed] ASC,
	[Order] ASC,
	[ID] ASC
)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


