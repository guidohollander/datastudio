SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationScenarioReplayMap', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationScenarioReplayMap (
        ReplayRunID UNIQUEIDENTIFIER NOT NULL,
        TableName SYSNAME NOT NULL,
        OldPkValue BIGINT NOT NULL,
        NewPkValue BIGINT NOT NULL,
        CapturedAt DATETIME2 NOT NULL CONSTRAINT DF_MigrationScenarioReplayMap_CapturedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_MigrationScenarioReplayMap PRIMARY KEY CLUSTERED (ReplayRunID, TableName, OldPkValue)
    );
END
GO
