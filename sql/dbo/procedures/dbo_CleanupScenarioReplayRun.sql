SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.CleanupScenarioReplayRun
    @ReplayRunID UNIQUEIDENTIFIER
WITH RECOMPILE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationScenarioReplayRun WHERE ReplayRunID = @ReplayRunID)
        THROW 50000, N'Unknown ReplayRunID.', 1;

    DECLARE @SourceRunID UNIQUEIDENTIFIER;
    SELECT @SourceRunID = SourceRunID FROM dbo.MigrationScenarioReplayRun WHERE ReplayRunID = @ReplayRunID;

    -- Delete rows created by a replay run, using the replay map to target exact PKs.
    -- Safety: this only deletes rows whose PKs are explicitly recorded in MigrationScenarioReplayMap.

    IF OBJECT_ID('tempdb..#Tables') IS NOT NULL DROP TABLE #Tables;
    IF OBJECT_ID('tempdb..#Rels') IS NOT NULL DROP TABLE #Rels;
    IF OBJECT_ID('tempdb..#Order') IS NOT NULL DROP TABLE #Order;

    SELECT DISTINCT m.TableName
    INTO #Tables
    FROM dbo.MigrationScenarioReplayMap m
    WHERE m.ReplayRunID = @ReplayRunID;

    SELECT
        c.ParentTable COLLATE DATABASE_DEFAULT AS ParentTable,
        c.ChildTable COLLATE DATABASE_DEFAULT AS ChildTable,
        c.ChildColumn COLLATE DATABASE_DEFAULT AS ChildColumn
    INTO #Rels
    FROM dbo.DataDictionaryRelationshipCandidate c
    WHERE c.Source = N'Scenario'
      AND c.EvidenceRunID = @SourceRunID
      AND c.IsActive = 1
      AND EXISTS (SELECT 1 FROM #Tables t WHERE t.TableName = c.ParentTable)
      AND EXISTS (SELECT 1 FROM #Tables t WHERE t.TableName = c.ChildTable);

    CREATE TABLE #Order (
        TableName NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL,
        Lvl INT NOT NULL
    );

    IF EXISTS (SELECT 1 FROM #Rels)
    BEGIN
        CREATE TABLE #State (
            TableName NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
            InDegree INT NOT NULL,
            Lvl INT NOT NULL,
            Processed BIT NOT NULL
        );

        INSERT INTO #State(TableName, InDegree, Lvl, Processed)
        SELECT
            CAST(t.TableName AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT,
            (
                SELECT COUNT(DISTINCT r.ParentTable)
                FROM #Rels r
                WHERE r.ChildTable = CAST(t.TableName AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT
                  AND r.ParentTable <> r.ChildTable
            ) AS InDegree,
            0,
            0
        FROM #Tables t;

        DECLARE @Remaining INT = (SELECT COUNT(*) FROM #State);
        DECLARE @CurTable NVARCHAR(128);
        DECLARE @CurLvl INT;

        WHILE @Remaining > 0
        BEGIN
            SELECT TOP 1
                @CurTable = s.TableName,
                @CurLvl = s.Lvl
            FROM #State s
            WHERE s.Processed = 0
              AND s.InDegree = 0
            ORDER BY s.Lvl, s.TableName;

            IF @CurTable IS NULL
            BEGIN
                INSERT INTO #Order(TableName, Lvl)
                SELECT s.TableName, 999
                FROM #State s
                WHERE s.Processed = 0
                ORDER BY s.TableName;

                UPDATE #State SET Processed = 1 WHERE Processed = 0;
                BREAK;
            END

            INSERT INTO #Order(TableName, Lvl) VALUES (@CurTable, @CurLvl);
            UPDATE #State SET Processed = 1 WHERE TableName = @CurTable;

            UPDATE child
            SET
                child.InDegree = CASE WHEN child.InDegree > 0 THEN child.InDegree - 1 ELSE 0 END,
                child.Lvl = CASE WHEN child.Lvl < @CurLvl + 1 THEN @CurLvl + 1 ELSE child.Lvl END
            FROM #State child
            WHERE child.Processed = 0
              AND EXISTS (
                  SELECT 1
                  FROM #Rels r
                  WHERE r.ParentTable = @CurTable
                    AND r.ChildTable = child.TableName
              );

            SET @CurTable = NULL;
            SET @Remaining = (SELECT COUNT(*) FROM #State WHERE Processed = 0);
        END
    END
    ELSE
    BEGIN
        INSERT INTO #Order(TableName, Lvl)
        SELECT CAST(t.TableName AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT, 0
        FROM #Tables t
        ORDER BY t.TableName;
    END

    DECLARE @t SYSNAME;
    DECLARE @PkColumn SYSNAME;
    DECLARE @PkType SYSNAME;
    DECLARE @PkTypeNorm SYSNAME;
    DECLARE @PkCount INT;
    DECLARE @PkPrecision INT;
    DECLARE @PkScale INT;
    DECLARE @PkCountSafe INT;
    DECLARE @PkPrecisionSafe INT;
    DECLARE @PkScaleSafe INT;
    DECLARE @PkColumnSafe SYSNAME;

    DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT o.TableName
        FROM #Order o
        ORDER BY o.Lvl DESC, o.TableName DESC;

    OPEN table_cursor;
    FETCH NEXT FROM table_cursor INTO @t;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT
            @PkCount = COUNT(*),
            @PkColumn = MAX(c.ColumnName),
            @PkType = MAX(c.TypeName),
            @PkPrecision = MAX(c.PrecisionValue),
            @PkScale = MAX(c.ScaleValue)
        FROM dbo.DataDictionaryColumn c
        JOIN dbo.DataDictionaryTable dt ON dt.TableObjectId = c.TableObjectId
        WHERE dt.SchemaName = N'dbo'
          AND dt.TableName = @t
          AND c.IsPrimaryKey = 1;

        IF @PkCount IS NULL OR @PkCount <> 1
        BEGIN
            SET @PkCountSafe = ISNULL(@PkCount, -1);
            RAISERROR(N'CleanupScenarioReplayRun only supports single-column PK tables. Table=%s, PkCount=%d', 16, 1, @t, @PkCountSafe);
            RETURN;
        END

        IF @PkType IS NULL
        BEGIN
            SET @PkColumnSafe = ISNULL(@PkColumn, N'<NULL>');
            RAISERROR(N'CleanupScenarioReplayRun could not determine PK type from DataDictionary. Table=%s, PkColumn=%s', 16, 1, @t, @PkColumnSafe);
            RETURN;
        END

        SET @PkTypeNorm = LOWER(LTRIM(RTRIM(@PkType)));

        IF @PkTypeNorm NOT IN (N'bigint', N'int', N'smallint', N'tinyint', N'numeric', N'decimal')
        BEGIN
            RAISERROR(N'CleanupScenarioReplayRun only supports int-compatible PK types. Table=%s, PkType=%s', 16, 1, @t, @PkTypeNorm);
            RETURN;
        END

        IF @PkTypeNorm IN (N'numeric', N'decimal') AND ISNULL(@PkScale, 0) <> 0
        BEGIN
            SET @PkPrecisionSafe = ISNULL(@PkPrecision, -1);
            SET @PkScaleSafe = ISNULL(@PkScale, -1);
            RAISERROR(N'CleanupScenarioReplayRun only supports numeric/decimal PK types with scale 0. Table=%s, PkType=%s, Precision=%d, Scale=%d', 16, 1, @t, @PkTypeNorm, @PkPrecisionSafe, @PkScaleSafe);
            RETURN;
        END

        IF @PkTypeNorm IN (N'numeric', N'decimal') AND ISNULL(@PkPrecision, 0) > 19
        BEGIN
            SET @PkPrecisionSafe = ISNULL(@PkPrecision, -1);
            SET @PkScaleSafe = ISNULL(@PkScale, -1);
            RAISERROR(N'CleanupScenarioReplayRun only supports numeric/decimal PK types with precision <= 19. Table=%s, PkType=%s, Precision=%d, Scale=%d', 16, 1, @t, @PkTypeNorm, @PkPrecisionSafe, @PkScaleSafe);
            RETURN;
        END

        DECLARE @Sql NVARCHAR(MAX) =
            N'DELETE tgt ' +
            N'FROM dbo.' + QUOTENAME(@t) + N' AS tgt ' +
            N'JOIN dbo.MigrationScenarioReplayMap m ' +
            N'  ON m.ReplayRunID = @ReplayRunID ' +
            N' AND m.TableName = @TableName ' +
            N' AND CONVERT(BIGINT, tgt.' + QUOTENAME(@PkColumn) + N') = m.NewPkValue;';

        EXEC sp_executesql
            @Sql,
            N'@ReplayRunID uniqueidentifier, @TableName sysname',
            @ReplayRunID = @ReplayRunID,
            @TableName = @t;

        FETCH NEXT FROM table_cursor INTO @t;
    END

    CLOSE table_cursor;
    DEALLOCATE table_cursor;

    DELETE FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @ReplayRunID;
    DELETE FROM dbo.MigrationScenarioReplayRun WHERE ReplayRunID = @ReplayRunID;
END
GO
