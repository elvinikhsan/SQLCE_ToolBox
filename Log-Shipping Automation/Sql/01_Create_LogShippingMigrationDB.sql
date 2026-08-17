/*
================================================================================
 01_Create_LogShippingMigrationDB.sql

 Creates the DBA_LogShippingMigration utility database and the tracking tables
 used by Start-LogShippingMigration.ps1 to drive and monitor the backup / copy
 / restore / log-shipping-configuration workflow.

 Run this ONCE on the TARGET instance before the first wave.
 Safe to re-run: all objects are created with existence checks.
================================================================================
*/
SET NOCOUNT ON;
GO

IF DB_ID(N'DBA_LogShippingMigration') IS NULL
BEGIN
    PRINT 'Creating database DBA_LogShippingMigration...';
    CREATE DATABASE [DBA_LogShippingMigration];
END
GO

ALTER DATABASE [DBA_LogShippingMigration] SET RECOVERY SIMPLE;
GO

USE [DBA_LogShippingMigration];
GO

/* ------------------------------------------------------------------------
   dbo.LogShippingFileMapping
   One row per logical file per database: the target physical path decided
   during the folder-mapping exercise (loaded from DatabaseFileMapping.csv).
   ------------------------------------------------------------------------ */
IF OBJECT_ID(N'dbo.LogShippingFileMapping', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LogShippingFileMapping
    (
        MappingId       INT IDENTITY(1,1)      NOT NULL,
        WaveName        NVARCHAR(100)           NULL,
        DatabaseName    NVARCHAR(128)           NOT NULL,
        LogicalFileName NVARCHAR(260)           NOT NULL,
        TargetPath      NVARCHAR(500)           NOT NULL,
        CreatedDate     DATETIME2(0)            NOT NULL CONSTRAINT DF_LogShippingFileMapping_CreatedDate DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_LogShippingFileMapping PRIMARY KEY CLUSTERED (MappingId),
        CONSTRAINT UQ_LogShippingFileMapping UNIQUE (DatabaseName, LogicalFileName)
    );
    PRINT 'Created dbo.LogShippingFileMapping';
END
GO

/* ------------------------------------------------------------------------
   dbo.LogShippingInitTracking
   One row per database per wave. Tracks status/timing/progress for each
   phase so backup/copy/restore can be run as separate steps at different
   times, and so progress can be monitored for long-running copies/restores.
   ------------------------------------------------------------------------ */
IF OBJECT_ID(N'dbo.LogShippingInitTracking', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LogShippingInitTracking
    (
        TrackingId                  INT IDENTITY(1,1)  NOT NULL,
        WaveName                    NVARCHAR(100)       NOT NULL,
        DatabaseName                NVARCHAR(128)       NOT NULL,
        DatabaseSizeMB              DECIMAL(18,2)       NULL,
        SequenceNo                  INT                 NULL,       -- processing order within the wave (smallest DB first)

        BackupStatus                NVARCHAR(20)        NOT NULL CONSTRAINT DF_LSIT_BackupStatus  DEFAULT ('Pending'),
        BackupStartTime             DATETIME2(0)        NULL,
        BackupEndTime               DATETIME2(0)        NULL,
        FullBackupFile               NVARCHAR(500)       NULL,
        LogBackupFile                NVARCHAR(500)       NULL,

        CopyStatus                  NVARCHAR(20)        NOT NULL CONSTRAINT DF_LSIT_CopyStatus    DEFAULT ('Pending'),
        CopyStartTime                 DATETIME2(0)        NULL,
        CopyEndTime                  DATETIME2(0)        NULL,
        CopyPercentComplete          DECIMAL(5,2)        NOT NULL CONSTRAINT DF_LSIT_CopyPct       DEFAULT (0),
        BytesTotal                   BIGINT              NULL,
        BytesCopied                  BIGINT              NULL,

        RestoreStatus                NVARCHAR(20)        NOT NULL CONSTRAINT DF_LSIT_RestoreStatus DEFAULT ('Pending'),
        RestoreStartTime             DATETIME2(0)        NULL,
        RestoreEndTime                DATETIME2(0)        NULL,
        RestorePercentComplete       DECIMAL(5,2)        NOT NULL CONSTRAINT DF_LSIT_RestorePct     DEFAULT (0),

        LogShippingConfigStatus      NVARCHAR(20)        NOT NULL CONSTRAINT DF_LSIT_LSConfigStatus DEFAULT ('Pending'),
        LogShippingConfigStartTime   DATETIME2(0)        NULL,
        LogShippingConfigEndTime     DATETIME2(0)        NULL,

        LastErrorMessage              NVARCHAR(MAX)       NULL,
        CreatedDate                   DATETIME2(0)        NOT NULL CONSTRAINT DF_LSIT_CreatedDate  DEFAULT (SYSUTCDATETIME()),
        ModifiedDate                  DATETIME2(0)        NOT NULL CONSTRAINT DF_LSIT_ModifiedDate DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_LogShippingInitTracking PRIMARY KEY CLUSTERED (TrackingId),
        CONSTRAINT UQ_LogShippingInitTracking UNIQUE (WaveName, DatabaseName),
        CONSTRAINT CK_LSIT_BackupStatus  CHECK (BackupStatus  IN ('Pending','InProgress','Complete','Failed','Skipped')),
        CONSTRAINT CK_LSIT_CopyStatus    CHECK (CopyStatus    IN ('Pending','InProgress','Complete','Failed','Skipped')),
        CONSTRAINT CK_LSIT_RestoreStatus CHECK (RestoreStatus IN ('Pending','InProgress','Complete','Failed','Skipped')),
        CONSTRAINT CK_LSIT_LSConfigStatus CHECK (LogShippingConfigStatus IN ('Pending','InProgress','Complete','Failed','Skipped'))
    );
    CREATE NONCLUSTERED INDEX IX_LogShippingInitTracking_Wave ON dbo.LogShippingInitTracking (WaveName, SequenceNo);
    PRINT 'Created dbo.LogShippingInitTracking';
END
GO

/* ------------------------------------------------------------------------
   dbo.vw_LogShippingProgress
   Convenience view for the DBA team to eyeball progress across a wave.
   ------------------------------------------------------------------------ */
IF OBJECT_ID(N'dbo.vw_LogShippingProgress', N'V') IS NOT NULL
    DROP VIEW dbo.vw_LogShippingProgress;
GO
CREATE VIEW dbo.vw_LogShippingProgress
AS
SELECT
    WaveName,
    SequenceNo,
    DatabaseName,
    DatabaseSizeMB,
    BackupStatus,
    CopyStatus,
    CopyPercentComplete,
    RestoreStatus,
    RestorePercentComplete,
    LogShippingConfigStatus,
    LastErrorMessage,
    ModifiedDate
FROM dbo.LogShippingInitTracking;
GO

PRINT 'DBA_LogShippingMigration schema is ready.';
GO
