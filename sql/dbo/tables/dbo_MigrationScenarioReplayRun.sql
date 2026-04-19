SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationScenarioReplayRun', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationScenarioReplayRun (
        ReplayRunID UNIQUEIDENTIFIER NOT NULL,
        SourceRunID UNIQUEIDENTIFIER NOT NULL,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_MigrationScenarioReplayRun_CreatedAt DEFAULT (SYSUTCDATETIME()),
        Notes NVARCHAR(2000) NULL,
        CONSTRAINT PK_MigrationScenarioReplayRun PRIMARY KEY CLUSTERED (ReplayRunID)
    );
END
GO
