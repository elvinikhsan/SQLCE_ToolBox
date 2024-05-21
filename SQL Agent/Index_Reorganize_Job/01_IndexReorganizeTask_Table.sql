USE [master]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IndexReorganizeTask](
	[ID] [int] NOT NULL,
	[DatabaseName] [sysname] NOT NULL,
	[SchemaID] [int] NULL,
	[SchemaName] [nvarchar](max) NULL,
	[ObjectID] [int] NULL,
	[ObjectName] [nvarchar](max) NULL,
	[ObjectType] [nvarchar](max) NULL,
	[IsMemoryOptimized] [bit] NULL,
	[IndexID] [int] NULL,
	[IndexName] [nvarchar](max) NULL,
	[IndexType] [int] NULL,
	[AllowPageLocks] [bit] NULL,
	[OnReadOnlyFileGroup] [bit] NULL,
	[ResumableIndexOperation] [bit] NULL,
	[PartitionID] [bigint] NULL,
	[PartitionNumber] [int] NULL,
	[PartitionCount] [int] NULL,
	[StartPosition] [int] NULL,
	[Order] [int] NOT NULL,
	[Selected] [bit] NOT NULL,
	[Completed] [bit] NOT NULL,
 CONSTRAINT [PK_IndexReorganizeTask] PRIMARY KEY CLUSTERED 
(
	[DatabaseName] ASC,
	[Selected] ASC,
	[Completed] ASC,
	[Order] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


