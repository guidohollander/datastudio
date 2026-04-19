SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.MigrationDomainField', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationDomainField (
        ObjectKey NVARCHAR(100) NOT NULL,
        ComponentKey NVARCHAR(100) NOT NULL,
        FieldKey NVARCHAR(100) NOT NULL,
        PhysicalColumn SYSNAME NOT NULL,
        DataType NVARCHAR(50) NOT NULL,
        MaxLength INT NULL,
        PrecisionValue INT NULL,
        ScaleValue INT NULL,
        IsRequired BIT NOT NULL,
        EnumKey NVARCHAR(100) NULL,
        LookupKey NVARCHAR(100) NULL,
        ExampleValue NVARCHAR(4000) NULL,
        Notes NVARCHAR(1000) NULL,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_MigrationDomainField_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_MigrationDomainField PRIMARY KEY CLUSTERED (ObjectKey, ComponentKey, FieldKey)
    );
END
GO
