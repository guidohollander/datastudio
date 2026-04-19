SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationScenario', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationScenario (
        ScenarioID INT IDENTITY(1,1) NOT NULL,
        Name NVARCHAR(200) NOT NULL,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_MigrationScenario_CreatedAt DEFAULT (SYSUTCDATETIME()),
        Notes NVARCHAR(1000) NULL,
        CONSTRAINT PK_MigrationScenario PRIMARY KEY CLUSTERED (ScenarioID),
        CONSTRAINT UQ_MigrationScenario_Name UNIQUE (Name)
    );
END
GO
