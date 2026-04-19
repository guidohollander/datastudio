SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationTableRelationships', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationTableRelationships (
        RelationshipID INT IDENTITY(1,1) NOT NULL,
        ParentTable SYSNAME NOT NULL,
        ParentColumn SYSNAME NOT NULL,
        ChildTable SYSNAME NOT NULL,
        ChildColumn SYSNAME NOT NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_MigrationTableRelationships_IsActive DEFAULT (1),
        Source NVARCHAR(100) NOT NULL CONSTRAINT DF_MigrationTableRelationships_Source DEFAULT (N'Manual'),
        Notes NVARCHAR(510) NULL,
        CONSTRAINT PK_MigrationTableRelationships PRIMARY KEY CLUSTERED (RelationshipID)
    );
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.MigrationTableRelationships')
      AND name = N'IX_MigrationTableRelationships_ActiveChild'
)
BEGIN
    CREATE INDEX IX_MigrationTableRelationships_ActiveChild
    ON dbo.MigrationTableRelationships (IsActive, ChildTable, ChildColumn)
    INCLUDE (ParentTable, ParentColumn, Source);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.MigrationTableRelationships')
      AND name = N'IX_MigrationTableRelationships_ActiveParentChild'
)
BEGIN
    CREATE INDEX IX_MigrationTableRelationships_ActiveParentChild
    ON dbo.MigrationTableRelationships (IsActive, ParentTable, ChildTable)
    INCLUDE (ChildColumn, ParentColumn, Source);
END
GO
