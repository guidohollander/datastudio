SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.DataDictionaryIndex', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DataDictionaryIndex (
        TableObjectId INT NOT NULL,
        IndexId INT NOT NULL,
        IndexName SYSNAME NULL,
        IsUnique BIT NOT NULL,
        IsPrimaryKey BIT NOT NULL,
        TypeDesc NVARCHAR(60) NOT NULL,
        FilterDefinition NVARCHAR(MAX) NULL,
        CapturedAt DATETIME2 NOT NULL CONSTRAINT DF_DataDictionaryIndex_CapturedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_DataDictionaryIndex PRIMARY KEY CLUSTERED (TableObjectId, IndexId)
    );
END
GO
