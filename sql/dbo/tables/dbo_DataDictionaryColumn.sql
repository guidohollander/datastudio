SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.DataDictionaryColumn', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DataDictionaryColumn (
        TableObjectId INT NOT NULL,
        ColumnId INT NOT NULL,
        ColumnName SYSNAME NOT NULL,
        TypeName SYSNAME NOT NULL,
        MaxLength INT NOT NULL,
        PrecisionValue INT NOT NULL,
        ScaleValue INT NOT NULL,
        IsNullable BIT NOT NULL,
        IsMandatory AS (CASE WHEN IsNullable = 0 THEN CONVERT(BIT, 1) ELSE CONVERT(BIT, 0) END) PERSISTED,
        IsIdentity BIT NOT NULL,
        DefaultDefinition NVARCHAR(MAX) NULL,
        IsComputed BIT NOT NULL,
        ComputedDefinition NVARCHAR(MAX) NULL,
        IsPrimaryKey BIT NOT NULL,
        CollationName SYSNAME NULL,
        CapturedAt DATETIME2 NOT NULL CONSTRAINT DF_DataDictionaryColumn_CapturedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_DataDictionaryColumn PRIMARY KEY CLUSTERED (TableObjectId, ColumnId)
    );
END
GO
