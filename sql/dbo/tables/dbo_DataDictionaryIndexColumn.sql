SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.DataDictionaryIndexColumn', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DataDictionaryIndexColumn (
        TableObjectId INT NOT NULL,
        IndexId INT NOT NULL,
        KeyOrdinal INT NOT NULL,
        ColumnId INT NOT NULL,
        IsDescending BIT NOT NULL,
        IsIncluded BIT NOT NULL,
        CapturedAt DATETIME2 NOT NULL CONSTRAINT DF_DataDictionaryIndexColumn_CapturedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_DataDictionaryIndexColumn PRIMARY KEY CLUSTERED (TableObjectId, IndexId, KeyOrdinal, ColumnId)
    );
END
GO
