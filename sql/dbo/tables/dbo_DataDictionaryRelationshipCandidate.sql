SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.DataDictionaryRelationshipCandidate', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DataDictionaryRelationshipCandidate (
        CandidateID BIGINT IDENTITY(1,1) NOT NULL,
        ParentTable NVARCHAR(512) NOT NULL,
        ParentColumn NVARCHAR(512) NOT NULL,
        ChildTable NVARCHAR(512) NOT NULL,
        ChildColumn NVARCHAR(512) NOT NULL,
        Source NVARCHAR(100) NOT NULL,
        EvidenceRunID UNIQUEIDENTIFIER NULL,
        Notes NVARCHAR(2000) NULL,
        Score INT NOT NULL CONSTRAINT DF_DataDictionaryRelationshipCandidate_Score DEFAULT (0),
        IsActive BIT NOT NULL CONSTRAINT DF_DataDictionaryRelationshipCandidate_IsActive DEFAULT (1),
        CapturedAt DATETIME2 NOT NULL CONSTRAINT DF_DataDictionaryRelationshipCandidate_CapturedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_DataDictionaryRelationshipCandidate PRIMARY KEY CLUSTERED (CandidateID)
    );

    CREATE INDEX IX_DataDictionaryRelationshipCandidate_SourceRun
    ON dbo.DataDictionaryRelationshipCandidate (Source, EvidenceRunID);

    CREATE INDEX IX_DataDictionaryRelationshipCandidate_ParentChild
    ON dbo.DataDictionaryRelationshipCandidate (ParentTable, ChildTable);

    CREATE INDEX IX_DataDictionaryRelationshipCandidate_ReplayLookup
    ON dbo.DataDictionaryRelationshipCandidate (IsActive, Source, EvidenceRunID, ChildTable)
    INCLUDE (ChildColumn, ParentTable, ParentColumn);
END
ELSE
BEGIN
    IF COL_LENGTH(N'dbo.DataDictionaryRelationshipCandidate', N'ParentTable') IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM sys.columns c
            WHERE c.object_id = OBJECT_ID(N'dbo.DataDictionaryRelationshipCandidate')
              AND c.name IN (N'ParentTable', N'ParentColumn', N'ChildTable', N'ChildColumn')
              AND c.max_length < 1024
        )
    BEGIN
        IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.DataDictionaryRelationshipCandidate') AND name = N'UX_DataDictionaryRelationshipCandidate_Key')
            DROP INDEX UX_DataDictionaryRelationshipCandidate_Key ON dbo.DataDictionaryRelationshipCandidate;

        IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.DataDictionaryRelationshipCandidate') AND name = N'UX_DataDictionaryRelationshipCandidate_Key_NoRun')
            DROP INDEX UX_DataDictionaryRelationshipCandidate_Key_NoRun ON dbo.DataDictionaryRelationshipCandidate;

        IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.DataDictionaryRelationshipCandidate') AND name = N'IX_DataDictionaryRelationshipCandidate_SourceRun')
            DROP INDEX IX_DataDictionaryRelationshipCandidate_SourceRun ON dbo.DataDictionaryRelationshipCandidate;

        IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.DataDictionaryRelationshipCandidate') AND name = N'IX_DataDictionaryRelationshipCandidate_ParentChild')
            DROP INDEX IX_DataDictionaryRelationshipCandidate_ParentChild ON dbo.DataDictionaryRelationshipCandidate;

        IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.DataDictionaryRelationshipCandidate') AND name = N'IX_DataDictionaryRelationshipCandidate_ReplayLookup')
            DROP INDEX IX_DataDictionaryRelationshipCandidate_ReplayLookup ON dbo.DataDictionaryRelationshipCandidate;

        ALTER TABLE dbo.DataDictionaryRelationshipCandidate ALTER COLUMN ParentTable NVARCHAR(512) NOT NULL;
        ALTER TABLE dbo.DataDictionaryRelationshipCandidate ALTER COLUMN ParentColumn NVARCHAR(512) NOT NULL;
        ALTER TABLE dbo.DataDictionaryRelationshipCandidate ALTER COLUMN ChildTable NVARCHAR(512) NOT NULL;
        ALTER TABLE dbo.DataDictionaryRelationshipCandidate ALTER COLUMN ChildColumn NVARCHAR(512) NOT NULL;

        CREATE INDEX IX_DataDictionaryRelationshipCandidate_SourceRun
        ON dbo.DataDictionaryRelationshipCandidate (Source, EvidenceRunID);

        CREATE INDEX IX_DataDictionaryRelationshipCandidate_ParentChild
        ON dbo.DataDictionaryRelationshipCandidate (ParentTable, ChildTable);

        CREATE INDEX IX_DataDictionaryRelationshipCandidate_ReplayLookup
        ON dbo.DataDictionaryRelationshipCandidate (IsActive, Source, EvidenceRunID, ChildTable)
        INCLUDE (ChildColumn, ParentTable, ParentColumn);
    END
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.DataDictionaryRelationshipCandidate')
      AND name = N'IX_DataDictionaryRelationshipCandidate_ReplayLookup'
)
BEGIN
    CREATE INDEX IX_DataDictionaryRelationshipCandidate_ReplayLookup
    ON dbo.DataDictionaryRelationshipCandidate (IsActive, Source, EvidenceRunID, ChildTable)
    INCLUDE (ChildColumn, ParentTable, ParentColumn);
END
GO
