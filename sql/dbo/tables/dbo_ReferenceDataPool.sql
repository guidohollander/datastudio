SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.ReferenceDataPool', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ReferenceDataPool (
        PoolID INT IDENTITY(1,1) NOT NULL,
        PoolName NVARCHAR(100) NOT NULL,
        Category NVARCHAR(50) NOT NULL,
        Value NVARCHAR(500) NOT NULL,
        Weight INT NOT NULL DEFAULT 1,
        Metadata NVARCHAR(MAX) NULL,
        CONSTRAINT PK_ReferenceDataPool PRIMARY KEY CLUSTERED (PoolID),
        CONSTRAINT UQ_ReferenceDataPool_PoolName_Value UNIQUE (PoolName, Value)
    );

    CREATE NONCLUSTERED INDEX IX_ReferenceDataPool_PoolName 
        ON dbo.ReferenceDataPool (PoolName) 
        INCLUDE (Category, Value, Weight);
END
GO
