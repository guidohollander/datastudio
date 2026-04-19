SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationDomainEnum', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationDomainEnum (
        EnumKey NVARCHAR(100) NOT NULL,
        DisplayName NVARCHAR(200) NOT NULL,
        Notes NVARCHAR(1000) NULL,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_MigrationDomainEnum_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_MigrationDomainEnum PRIMARY KEY CLUSTERED (EnumKey)
    );
END
GO
