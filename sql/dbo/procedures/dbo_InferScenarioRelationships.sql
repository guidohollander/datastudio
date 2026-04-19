SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.InferScenarioRelationships
    @RunID UNIQUEIDENTIFIER,
    @AlsoInsertIntoRegistry BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationScenarioRun WHERE RunID = @RunID)
        THROW 50000, N'Unknown RunID.', 1;

    ;WITH NewRows AS (
        SELECT TableName, PkValue
        FROM dbo.MigrationScenarioRow
        WHERE RunID = @RunID
    ),
    CandidatePairs AS (
        SELECT
            c.TableName AS ChildTable,
            c.PkColumn AS ChildPkColumn,
            c.PkValue AS ChildPkValue,
            j.[key] AS ChildColumn,
            TRY_CONVERT(BIGINT, j.[value]) AS ParentPkValue
        FROM dbo.MigrationScenarioRow c
        CROSS APPLY OPENJSON(c.RowJson) j
        WHERE c.RunID = @RunID
          AND j.[type] IN (1,2)
          AND j.[key] COLLATE DATABASE_DEFAULT <> c.PkColumn COLLATE DATABASE_DEFAULT
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
            p.ChildTable COLLATE DATABASE_DEFAULT AS ChildTable,
            p.ChildColumn COLLATE DATABASE_DEFAULT AS ChildColumn,
            pr.TableName COLLATE DATABASE_DEFAULT AS ParentTable,
            CAST(pr.PkValue AS NVARCHAR(256)) AS NotesPk
        FROM CandidatePairs p
        JOIN NewRows pr
          ON pr.PkValue = p.ParentPkValue
         AND pr.TableName <> p.ChildTable
        GROUP BY p.ChildTable, p.ChildColumn, pr.TableName, pr.PkValue
    )
    SELECT *
    INTO #Detected
    FROM Matched;

    IF @AlsoInsertIntoRegistry = 1
    BEGIN
        INSERT INTO dbo.MigrationTableRelationships (ParentTable, ParentColumn, ChildTable, ChildColumn, IsActive, Source, Notes)
        SELECT
            d.ParentTable,
            N'ID' AS ParentColumn,
            d.ChildTable,
            d.ChildColumn,
            1,
            N'DetectedScenario',
            N'RunID=' + CONVERT(NVARCHAR(36), @RunID)
        FROM #Detected d
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.MigrationTableRelationships r
            WHERE r.ParentTable COLLATE DATABASE_DEFAULT = d.ParentTable COLLATE DATABASE_DEFAULT
              AND r.ChildTable COLLATE DATABASE_DEFAULT = d.ChildTable COLLATE DATABASE_DEFAULT
              AND r.ChildColumn COLLATE DATABASE_DEFAULT = d.ChildColumn COLLATE DATABASE_DEFAULT
              AND r.IsActive = 1
        );
    END

    -- Use MERGE to handle duplicates gracefully
    MERGE dbo.MigrationScenarioRelationship AS target
    USING (
        SELECT DISTINCT
            @RunID AS RunID,
            r.RelationshipID,
            N'Inferred from scenario rows' AS Notes
        FROM dbo.MigrationTableRelationships r
        JOIN #Detected d
          ON d.ParentTable COLLATE DATABASE_DEFAULT = r.ParentTable COLLATE DATABASE_DEFAULT
         AND d.ChildTable COLLATE DATABASE_DEFAULT = r.ChildTable COLLATE DATABASE_DEFAULT
         AND d.ChildColumn COLLATE DATABASE_DEFAULT = r.ChildColumn COLLATE DATABASE_DEFAULT
    ) AS source
    ON target.RunID = source.RunID AND target.RelationshipID = source.RelationshipID
    WHEN NOT MATCHED THEN
        INSERT (RunID, RelationshipID, Notes)
        VALUES (source.RunID, source.RelationshipID, source.Notes);

    SELECT ParentTable, ChildTable, ChildColumn
    FROM #Detected
    ORDER BY ParentTable, ChildTable, ChildColumn;
END
GO
