SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationScenarioRelationship', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationScenarioRelationship (
        RunID UNIQUEIDENTIFIER NOT NULL,
        RelationshipID INT NOT NULL,
        AddedAt DATETIME2 NOT NULL CONSTRAINT DF_MigrationScenarioRelationship_AddedAt DEFAULT (SYSUTCDATETIME()),
        Notes NVARCHAR(1000) NULL,
        CONSTRAINT PK_MigrationScenarioRelationship PRIMARY KEY CLUSTERED (RunID, RelationshipID)
    );
END
GO
