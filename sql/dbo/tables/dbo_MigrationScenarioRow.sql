SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationScenarioRow', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationScenarioRow (
        RunID UNIQUEIDENTIFIER NOT NULL,
        TableName SYSNAME NOT NULL,
        PkColumn SYSNAME NOT NULL,
        PkValue BIGINT NOT NULL,
        CapturedAt DATETIME2 NOT NULL CONSTRAINT DF_MigrationScenarioRow_CapturedAt DEFAULT (SYSUTCDATETIME()),
        RowJson NVARCHAR(MAX) NOT NULL,
        ChangeType VARCHAR(10) NULL,
        CONSTRAINT PK_MigrationScenarioRow PRIMARY KEY CLUSTERED (RunID, TableName, PkValue)
    );
END
ELSE
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.MigrationScenarioRow') AND name = 'ChangeType')
    BEGIN
        ALTER TABLE dbo.MigrationScenarioRow ADD ChangeType VARCHAR(10) NULL;
    END
    
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.MigrationScenarioRow') AND name = 'ExcludeFromReplay')
    BEGIN
        ALTER TABLE dbo.MigrationScenarioRow ADD ExcludeFromReplay BIT NOT NULL DEFAULT 0;
    END
END
GO
