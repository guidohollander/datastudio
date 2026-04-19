SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.RefreshDataDictionaryRelationshipCandidates
    @SchemaName SYSNAME = N'dbo',
    @IncludePatternBased BIT = 1,
    @IncludeScenarioValidated BIT = 1,
    @RunID UNIQUEIDENTIFIER = NULL
WITH RECOMPILE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2 = SYSUTCDATETIME();

    DECLARE @ScopedTables TABLE (TableName SYSNAME PRIMARY KEY);
    IF @RunID IS NOT NULL
    BEGIN
        INSERT INTO @ScopedTables(TableName)
        SELECT DISTINCT TableName
        FROM dbo.MigrationScenarioRow
        WHERE RunID = @RunID;
    END

    IF @IncludePatternBased = 1
    BEGIN
        DELETE FROM dbo.DataDictionaryRelationshipCandidate
        WHERE Source = N'Pattern'
          AND EvidenceRunID IS NULL;

        ;WITH IdCols AS (
            SELECT
                t.TableName,
                c.ColumnName,
                c.TypeName
            FROM dbo.DataDictionaryColumn c
            JOIN dbo.DataDictionaryTable t ON t.TableObjectId = c.TableObjectId
            WHERE t.SchemaName = @SchemaName
              AND t.IsView = 0
              AND (@RunID IS NULL OR EXISTS (SELECT 1 FROM @ScopedTables st WHERE st.TableName = t.TableName))
              AND (
                    c.ColumnName LIKE '%ID'
                    OR c.ColumnName LIKE '%Id'
                    OR c.ColumnName LIKE '%GUID'
                    OR c.ColumnName LIKE '%Guid'
                  )
        ),
        PkCols AS (
            SELECT
                t.TableName,
                c.ColumnName,
                c.TypeName
            FROM dbo.DataDictionaryColumn c
            JOIN dbo.DataDictionaryTable t ON t.TableObjectId = c.TableObjectId
            WHERE t.SchemaName = @SchemaName
              AND t.IsView = 0
              AND (@RunID IS NULL OR EXISTS (SELECT 1 FROM @ScopedTables st WHERE st.TableName = t.TableName))
              AND c.IsPrimaryKey = 1
        ),
        DirectNameMatches AS (
            SELECT
                pk.TableName AS ParentTable,
                pk.ColumnName AS ParentColumn,
                ch.TableName AS ChildTable,
                ch.ColumnName AS ChildColumn
            FROM IdCols ch
            JOIN PkCols pk
              ON pk.TableName <> ch.TableName
             AND pk.ColumnName = ch.ColumnName
        ),
        CaseIdMatches AS (
            SELECT
                N'CMFCASE' AS ParentTable,
                N'ID' AS ParentColumn,
                ch.TableName AS ChildTable,
                ch.ColumnName AS ChildColumn
            FROM IdCols ch
            WHERE UPPER(ch.ColumnName) = N'CASEID'
        ),
        RecordIdMatches AS (
            SELECT
                N'CMFRECORD' AS ParentTable,
                N'ID' AS ParentColumn,
                ch.TableName AS ChildTable,
                ch.ColumnName AS ChildColumn
            FROM IdCols ch
            WHERE UPPER(ch.ColumnName) LIKE N'%RECORDID'
              AND ch.TableName <> N'CMFRECORD'
              AND ch.TableName NOT LIKE N'SC\_%' ESCAPE N'\'
        ),
        Candidates AS (
            SELECT * FROM DirectNameMatches
            UNION ALL
            SELECT * FROM CaseIdMatches
            UNION ALL
            SELECT * FROM RecordIdMatches
        )
        INSERT INTO dbo.DataDictionaryRelationshipCandidate (ParentTable, ParentColumn, ChildTable, ChildColumn, Source, EvidenceRunID, Notes, Score, IsActive, CapturedAt)
        SELECT
            LEFT(c.ParentTable, 512),
            LEFT(c.ParentColumn, 512),
            LEFT(c.ChildTable, 512),
            LEFT(c.ChildColumn, 512),
            N'Pattern' AS Source,
            NULL,
            LEFT(N'Pattern candidate (scoped; name-matched PK or CASEID->CMFCASE)', 2000),
            25,
            1,
            @Now
        FROM Candidates c
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.DataDictionaryRelationshipCandidate x
            WHERE x.ParentTable = c.ParentTable
              AND x.ParentColumn = c.ParentColumn
              AND x.ChildTable = c.ChildTable
              AND x.ChildColumn = c.ChildColumn
              AND x.Source = N'Pattern'
              AND x.EvidenceRunID IS NULL
        );
    END

    IF @IncludeScenarioValidated = 1
    BEGIN
        DECLARE @Runs TABLE (RunID UNIQUEIDENTIFIER PRIMARY KEY);

        IF @RunID IS NOT NULL
            INSERT INTO @Runs(RunID) VALUES (@RunID);
        ELSE
            INSERT INTO @Runs(RunID)
            SELECT DISTINCT RunID FROM dbo.MigrationScenarioRow;

        DELETE x
        FROM dbo.DataDictionaryRelationshipCandidate x
        JOIN @Runs r ON r.RunID = x.EvidenceRunID
        WHERE x.Source = N'Scenario';

        ;WITH NewRows AS (
            SELECT r.RunID, r.TableName, r.PkValue
            FROM dbo.MigrationScenarioRow r
            JOIN @Runs rr ON rr.RunID = r.RunID
        ),
        CandidatePairs AS (
            SELECT
                c.RunID,
                c.TableName AS ChildTable,
                j.[key] COLLATE DATABASE_DEFAULT AS ChildColumn,
                TRY_CONVERT(BIGINT, j.[value]) AS ParentPkValue
            FROM dbo.MigrationScenarioRow c
            JOIN @Runs rr ON rr.RunID = c.RunID
            CROSS APPLY OPENJSON(c.RowJson) j
            WHERE j.[type] IN (1,2)
              AND (
                    j.[key] COLLATE DATABASE_DEFAULT LIKE '%ID'
                    OR j.[key] COLLATE DATABASE_DEFAULT LIKE '%Id'
                    OR j.[key] COLLATE DATABASE_DEFAULT LIKE '%Guid'
                    OR j.[key] COLLATE DATABASE_DEFAULT LIKE '%GUID'
                  )
              AND TRY_CONVERT(BIGINT, j.[value]) IS NOT NULL
        ),
        Matched AS (
            SELECT
                p.RunID,
                pr.TableName COLLATE DATABASE_DEFAULT AS ParentTable,
                p.ChildTable COLLATE DATABASE_DEFAULT AS ChildTable,
                p.ChildColumn
            FROM CandidatePairs p
            JOIN NewRows pr
              ON pr.RunID = p.RunID
             AND pr.PkValue = p.ParentPkValue
             AND pr.TableName <> p.ChildTable
            GROUP BY p.RunID, pr.TableName, p.ChildTable, p.ChildColumn
        )
        INSERT INTO dbo.DataDictionaryRelationshipCandidate (ParentTable, ParentColumn, ChildTable, ChildColumn, Source, EvidenceRunID, Notes, Score, IsActive, CapturedAt)
        SELECT DISTINCT
            LEFT(m.ParentTable, 512),
            N'ID',
            LEFT(m.ChildTable, 512),
            LEFT(m.ChildColumn, 512),
            N'Scenario',
            m.RunID,
            LEFT(N'Observed in scenario rows', 2000),
            100,
            1,
            @Now
        FROM Matched m;
    END
END
GO
