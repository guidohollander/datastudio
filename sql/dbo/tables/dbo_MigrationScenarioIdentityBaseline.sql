SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationScenarioIdentityBaseline', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationScenarioIdentityBaseline (
        RunID UNIQUEIDENTIFIER NOT NULL,
        TableName SYSNAME NOT NULL,
        IdentityColumn SYSNAME NULL,
        LastIdentityValue BIGINT NULL,
        CapturedAt DATETIME2 NOT NULL CONSTRAINT DF_MigrationScenarioIdentityBaseline_CapturedAt DEFAULT (SYSUTCDATETIME())
    );
END
GO
