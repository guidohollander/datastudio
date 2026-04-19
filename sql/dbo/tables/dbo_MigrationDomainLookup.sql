SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationDomainLookup', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationDomainLookup (
        LookupKey NVARCHAR(100) NOT NULL,
        DisplayName NVARCHAR(200) NOT NULL,
        SourceTable SYSNAME NOT NULL,
        SourceValueColumn SYSNAME NOT NULL,
        SourceLabelColumn SYSNAME NULL,
        WhereClause NVARCHAR(2000) NULL,
        Notes NVARCHAR(1000) NULL,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_MigrationDomainLookup_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_MigrationDomainLookup PRIMARY KEY CLUSTERED (LookupKey)
    );
END
GO
