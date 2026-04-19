SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationDomainEnumValue', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationDomainEnumValue (
        EnumKey NVARCHAR(100) NOT NULL,
        ValueKey NVARCHAR(200) NOT NULL,
        DisplayName NVARCHAR(200) NULL,
        SortOrder INT NOT NULL CONSTRAINT DF_MigrationDomainEnumValue_SortOrder DEFAULT (0),
        IsActive BIT NOT NULL CONSTRAINT DF_MigrationDomainEnumValue_IsActive DEFAULT (1),
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_MigrationDomainEnumValue_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_MigrationDomainEnumValue PRIMARY KEY CLUSTERED (EnumKey, ValueKey)
    );
END
GO
