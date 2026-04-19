SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationDomainObject', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationDomainObject (
        ObjectKey NVARCHAR(100) NOT NULL,
        DisplayName NVARCHAR(200) NOT NULL,
        Notes NVARCHAR(1000) NULL,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_MigrationDomainObject_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_MigrationDomainObject PRIMARY KEY CLUSTERED (ObjectKey)
    );
END
GO
