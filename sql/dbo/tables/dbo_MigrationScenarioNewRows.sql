SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationScenarioNewRows', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationScenarioNewRows (
        RunID UNIQUEIDENTIFIER NOT NULL,
        TableName SYSNAME NOT NULL,
        NewIdentityValue BIGINT NOT NULL,
        FoundAt DATETIME2 NOT NULL
    );
END
GO
