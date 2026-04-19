SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.DataDictionaryTable', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DataDictionaryTable (
        TableObjectId INT NOT NULL,
        SchemaName SYSNAME NOT NULL,
        TableName SYSNAME NOT NULL,
        IsView BIT NOT NULL,
        CreatedAt DATETIME2 NOT NULL,
        ModifiedAt DATETIME2 NOT NULL,
        CapturedAt DATETIME2 NOT NULL CONSTRAINT DF_DataDictionaryTable_CapturedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_DataDictionaryTable PRIMARY KEY CLUSTERED (TableObjectId)
    );
END
GO
