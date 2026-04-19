SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationDomainComponent', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationDomainComponent (
        ObjectKey NVARCHAR(100) NOT NULL,
        ComponentKey NVARCHAR(100) NOT NULL,
        DisplayName NVARCHAR(200) NOT NULL,
        PhysicalTable SYSNAME NOT NULL,
        MinOccurs INT NOT NULL,
        MaxOccurs INT NULL,
        SortOrder INT NOT NULL CONSTRAINT DF_MigrationDomainComponent_SortOrder DEFAULT (0),
        Notes NVARCHAR(1000) NULL,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_MigrationDomainComponent_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_MigrationDomainComponent PRIMARY KEY CLUSTERED (ObjectKey, ComponentKey)
    );
END
GO
