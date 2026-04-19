SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.ReplayScenarioRun
    @SourceRunID UNIQUEIDENTIFIER,
    @Times INT = 1,
    @FirstNameBase NVARCHAR(200) = NULL,
    @LastNameBase NVARCHAR(200) = NULL,
    @OverridesJson NVARCHAR(MAX) = NULL,
    @Notes NVARCHAR(2000) = NULL,
    @Commit BIT = 0,
    @ManageTransaction BIT = 1  -- Set to 0 when called from INSERT-EXEC context
AS
BEGIN
    SET NOCOUNT ON;

    IF @Times IS NULL OR @Times < 1
        THROW 50000, N'@Times must be >= 1', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationScenarioRow WHERE RunID = @SourceRunID)
        THROW 50000, N'No captured scenario rows found for SourceRunID.', 1;

    DECLARE @i INT = 1;

    WHILE @i <= @Times
    BEGIN
        DECLARE @ReplayRunID UNIQUEIDENTIFIER = NEWID();
        DECLARE @First NVARCHAR(200) = @FirstNameBase;
        DECLARE @Last NVARCHAR(200) = @LastNameBase;

        IF @First IS NOT NULL AND @Times > 1
            SET @First = @First + N' ' + CONVERT(NVARCHAR(10), @i);

        IF @Last IS NOT NULL AND @Times > 1
            SET @Last = @Last + N' ' + CONVERT(NVARCHAR(10), @i);

        BEGIN TRY
            IF @ManageTransaction = 1
                BEGIN TRANSACTION;

            IF OBJECT_ID('tempdb..#Tables') IS NOT NULL DROP TABLE #Tables;
            IF OBJECT_ID('tempdb..#Rels') IS NOT NULL DROP TABLE #Rels;
            IF OBJECT_ID('tempdb..#Order') IS NOT NULL DROP TABLE #Order;
            IF OBJECT_ID('tempdb..#State') IS NOT NULL DROP TABLE #State;

            INSERT INTO dbo.MigrationScenarioReplayRun (ReplayRunID, SourceRunID, Notes)
            VALUES (@ReplayRunID, @SourceRunID, @Notes);

            DELETE FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @ReplayRunID;

            -- Determine involved tables
            SELECT DISTINCT r.TableName
            INTO #Tables
            FROM dbo.MigrationScenarioRow r
            WHERE r.RunID = @SourceRunID;

            -- Relationships limited to involved tables.
            -- We always include Scenario-validated candidates (run-specific) AND Pattern candidates
            -- because some critical ordering edges (e.g. *RECORDID -> CMFRECORD.ID) may be pattern-only.
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

            INSERT INTO #Rels(ParentTable, ChildTable, ChildColumn)
            SELECT
                c.ParentTable COLLATE DATABASE_DEFAULT,
                c.ChildTable COLLATE DATABASE_DEFAULT,
                c.ChildColumn COLLATE DATABASE_DEFAULT
            FROM dbo.DataDictionaryRelationshipCandidate c
            WHERE c.Source = N'Pattern'
              AND c.EvidenceRunID IS NULL
              AND c.IsActive = 1
              AND EXISTS (SELECT 1 FROM #Tables t WHERE t.TableName = c.ParentTable)
              AND EXISTS (SELECT 1 FROM #Tables t WHERE t.TableName = c.ChildTable)
              AND NOT EXISTS (
                  SELECT 1
                  FROM #Rels r
                  WHERE r.ParentTable = c.ParentTable COLLATE DATABASE_DEFAULT
                    AND r.ChildTable = c.ChildTable COLLATE DATABASE_DEFAULT
                    AND r.ChildColumn = c.ChildColumn COLLATE DATABASE_DEFAULT
              );

            -- Always merge MigrationTableRelationships (manually defined + analysis-discovered)
            -- so that CASEID remapping and other critical FK relationships are always available.
            INSERT INTO #Rels(ParentTable, ChildTable, ChildColumn)
            SELECT
                r.ParentTable COLLATE DATABASE_DEFAULT,
                r.ChildTable COLLATE DATABASE_DEFAULT,
                r.ChildColumn COLLATE DATABASE_DEFAULT
            FROM dbo.MigrationTableRelationships r
            WHERE r.IsActive = 1
              AND EXISTS (SELECT 1 FROM #Tables t WHERE t.TableName = r.ParentTable)
              AND EXISTS (SELECT 1 FROM #Tables t WHERE t.TableName = r.ChildTable)
              AND NOT EXISTS (
                  SELECT 1 FROM #Rels x
                  WHERE x.ParentTable = r.ParentTable COLLATE DATABASE_DEFAULT
                    AND x.ChildTable = r.ChildTable COLLATE DATABASE_DEFAULT
                    AND x.ChildColumn = r.ChildColumn COLLATE DATABASE_DEFAULT
              );

            -- Compute dependency order (parents first) without recursion (cycles are possible).
            CREATE TABLE #Order (
                TableName NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL,
                Lvl INT NOT NULL
            );

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
                0 AS Lvl,
                0 AS Processed
            FROM #Tables t;

            -- CMFRECORD is foundational for many "record" tables; if relationship discovery introduces cycles,
            -- force CMFRECORD to be scheduled first so record-id PK mapping is available.
            IF EXISTS (SELECT 1 FROM #State WHERE TableName = N'CMFRECORD')
                UPDATE #State SET InDegree = 0, Lvl = 0 WHERE TableName = N'CMFRECORD';

            -- CMFCASE is foundational for many case-centric tables (some use CASEID as both PK and FK);
            -- force CMFCASE early so CASEID remapping is possible even in the presence of cycles.
            IF EXISTS (SELECT 1 FROM #State WHERE TableName = N'CMFCASE')
                UPDATE #State SET InDegree = 0, Lvl = 0 WHERE TableName = N'CMFCASE';

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
                    -- Cycle fallback: append remaining in deterministic order.
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

                -- Reduce indegree of children and propagate level.
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

            DECLARE @Table SYSNAME;

            DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT TableName
                FROM #Order
                ORDER BY Lvl, TableName;

            OPEN table_cursor;
            FETCH NEXT FROM table_cursor INTO @Table;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                DECLARE @ObjectId INT = OBJECT_ID(QUOTENAME(N'dbo') + N'.' + QUOTENAME(@Table));

                -- Determine the actual (single-column) PK from the data dictionary.
                DECLARE @PkColumn SYSNAME;
                DECLARE @PkType SYSNAME;
                DECLARE @PkCount INT;
                DECLARE @PkPrecision INT;
                DECLARE @PkScale INT;
                DECLARE @PkTypeNorm SYSNAME;
                DECLARE @PkIsIdentity BIT;
                DECLARE @NextPk BIGINT;

                SELECT
                    @PkCount = COUNT(*),
                    @PkColumn = MAX(CASE WHEN c.IsPrimaryKey = 1 THEN c.ColumnName END),
                    @PkType = MAX(CASE WHEN c.IsPrimaryKey = 1 THEN c.TypeName END),
                    @PkPrecision = MAX(CASE WHEN c.IsPrimaryKey = 1 THEN c.PrecisionValue END),
                    @PkScale = MAX(CASE WHEN c.IsPrimaryKey = 1 THEN c.ScaleValue END),
                    @PkIsIdentity = CONVERT(BIT, MAX(CASE WHEN c.IsPrimaryKey = 1 THEN CONVERT(INT, c.IsIdentity) END))
                FROM dbo.DataDictionaryColumn c
                JOIN dbo.DataDictionaryTable dt ON dt.TableObjectId = c.TableObjectId
                WHERE dt.SchemaName = N'dbo'
                  AND dt.TableName = @Table
                  AND c.IsPrimaryKey = 1;

                IF @PkCount IS NULL OR @PkCount = 0
                BEGIN
                    -- Some tables in this domain have no declared PK constraint but are still logically keyed.
                    -- Fall back to the scenario-captured key column.
                    DECLARE @ScenarioPkCount INT;
                    DECLARE @ScenarioPkColumn SYSNAME;

                    SELECT
                        @ScenarioPkCount = COUNT(DISTINCT r.PkColumn),
                        @ScenarioPkColumn = MAX(r.PkColumn)
                    FROM dbo.MigrationScenarioRow r
                    WHERE r.RunID = @SourceRunID
                      AND r.TableName = @Table;

                    IF ISNULL(@ScenarioPkCount, 0) <> 1 OR @ScenarioPkColumn IS NULL
                    BEGIN
                        DECLARE @NoPkMsg NVARCHAR(2048) = N'No primary key found in data dictionary for table ' + @Table + N' and scenario has no single PkColumn.';
                        THROW 50000, @NoPkMsg, 1;
                    END

                    SELECT
                        @PkCount = 1,
                        @PkColumn = c.ColumnName,
                        @PkType = c.TypeName,
                        @PkPrecision = c.PrecisionValue,
                        @PkScale = c.ScaleValue,
                        @PkIsIdentity = c.IsIdentity
                    FROM dbo.DataDictionaryColumn c
                    JOIN dbo.DataDictionaryTable dt ON dt.TableObjectId = c.TableObjectId
                    WHERE dt.SchemaName = N'dbo'
                      AND dt.TableName = @Table
                      AND c.ColumnName = @ScenarioPkColumn;

                    IF @PkColumn IS NULL
                    BEGIN
                        DECLARE @NoPkColMsg NVARCHAR(2048) = N'Scenario PkColumn ' + ISNULL(@ScenarioPkColumn, N'(null)') + N' was not found in data dictionary for table ' + @Table + N'.';
                        THROW 50000, @NoPkColMsg, 1;
                    END
                END

                IF @PkCount > 1
                    THROW 50000, N'Composite primary key not supported by ReplayScenarioRun yet.', 1;

                SET @PkTypeNorm = LOWER(LTRIM(RTRIM(@PkType)));

                IF @PkTypeNorm NOT IN (N'bigint', N'int', N'smallint', N'tinyint', N'numeric', N'decimal')
                    THROW 50000, N'Primary key type not supported for replay-map (must be int-compatible).', 1;

                IF @PkTypeNorm IN (N'numeric', N'decimal') AND ISNULL(@PkScale, 0) <> 0
                    THROW 50000, N'Primary key type not supported for replay-map (numeric/decimal scale must be 0).', 1;

                IF @PkTypeNorm IN (N'numeric', N'decimal') AND ISNULL(@PkPrecision, 0) > 19
                    THROW 50000, N'Primary key type not supported for replay-map (numeric/decimal precision must be <= 19).', 1;

                -- For non-identity PK tables, we must generate new PK values to avoid collisions.
                SET @NextPk = NULL;
                IF ISNULL(@PkIsIdentity, 0) = 0
                BEGIN
                    DECLARE @SqlNextPk NVARCHAR(MAX) =
                        N'SELECT @NextPk = ISNULL(MAX(CONVERT(BIGINT, ' + QUOTENAME(@PkColumn) + N')), 0) + 1 ' +
                        N'FROM dbo.' + QUOTENAME(@Table) + N' WITH (UPDLOCK, HOLDLOCK);';

                    EXEC sp_executesql
                        @SqlNextPk,
                        N'@NextPk bigint OUTPUT',
                        @NextPk = @NextPk OUTPUT;
                END

                -- Build column list (exclude identity + computed)
                DECLARE @WithCols NVARCHAR(MAX) = N'';
                DECLARE @InsertCols NVARCHAR(MAX) = N'';
                DECLARE @SelectCols NVARCHAR(MAX) = N'';

                ;WITH Cols AS (
                    SELECT
                        c.ColumnId,
                        c.ColumnName,
                        c.TypeName,
                        c.MaxLength,
                        c.PrecisionValue,
                        c.ScaleValue,
                        c.IsNullable,
                        c.IsIdentity,
                        c.IsComputed
                    FROM dbo.DataDictionaryColumn c
                    JOIN dbo.DataDictionaryTable t ON t.TableObjectId = c.TableObjectId
                    WHERE t.SchemaName = N'dbo'
                      AND t.TableName = @Table
                      AND c.IsIdentity = 0
                      AND c.IsComputed = 0
                )
                SELECT
                    @WithCols = STRING_AGG(
                        QUOTENAME(ColumnName) + N' ' +
                        CASE
                            WHEN TypeName IN (N'nvarchar', N'nchar') AND MaxLength = -1 THEN TypeName + N'(max)'
                            WHEN TypeName IN (N'nvarchar', N'nchar') THEN TypeName + N'(' + CONVERT(NVARCHAR(10), MaxLength/2) + N')'
                            WHEN TypeName IN (N'varchar', N'char', N'varbinary', N'binary') AND MaxLength = -1 THEN TypeName + N'(max)'
                            WHEN TypeName IN (N'varchar', N'char', N'varbinary', N'binary') THEN TypeName + N'(' + CONVERT(NVARCHAR(10), MaxLength) + N')'
                            -- Use nvarchar for date/datetime types to avoid conversion errors in OPENJSON
                            WHEN TypeName IN (N'date', N'datetime', N'datetime2', N'smalldatetime', N'datetimeoffset', N'time') THEN N'nvarchar(50)'
                            -- Use nvarchar for numeric types to avoid conversion errors when JSON contains string values
                            WHEN TypeName IN (N'bigint', N'int', N'smallint', N'tinyint', N'decimal', N'numeric', N'float', N'real', N'money', N'smallmoney') THEN N'nvarchar(50)'
                            ELSE TypeName
                        END +
                        N' ''$.' + REPLACE(ColumnName, '''', '''''') + N'''',
                        N', '
                    ) WITHIN GROUP (ORDER BY ColumnId),
                    @InsertCols = STRING_AGG(QUOTENAME(ColumnName), N', ') WITHIN GROUP (ORDER BY ColumnId),
                    @SelectCols = STRING_AGG(
                        CASE
                            -- Convert string to date/datetime types
                            WHEN TypeName IN (N'date', N'datetime', N'datetime2', N'smalldatetime') THEN 
                                N'TRY_CONVERT(' + TypeName + N', src.' + QUOTENAME(ColumnName) + N', 126)'
                            WHEN TypeName = N'datetimeoffset' THEN
                                N'TRY_CONVERT(datetimeoffset, src.' + QUOTENAME(ColumnName) + N', 127)'
                            WHEN TypeName = N'time' THEN
                                N'TRY_CONVERT(time, src.' + QUOTENAME(ColumnName) + N')'
                            -- Convert string to numeric types (handles nvarchar to bigint/int conversion)
                            WHEN TypeName IN (N'bigint', N'int', N'smallint', N'tinyint') THEN
                                N'TRY_CONVERT(' + TypeName + N', src.' + QUOTENAME(ColumnName) + N')'
                            WHEN TypeName IN (N'decimal', N'numeric') THEN
                                N'TRY_CONVERT(' + TypeName + N'(' + CONVERT(NVARCHAR(10), PrecisionValue) + N',' + CONVERT(NVARCHAR(10), ScaleValue) + N'), src.' + QUOTENAME(ColumnName) + N')'
                            WHEN TypeName IN (N'float', N'real', N'money', N'smallmoney') THEN
                                N'TRY_CONVERT(' + TypeName + N', src.' + QUOTENAME(ColumnName) + N')'
                            ELSE N'src.' + QUOTENAME(ColumnName)
                        END,
                        N', '
                    ) WITHIN GROUP (ORDER BY ColumnId)
                FROM Cols;

                DECLARE row_cursor CURSOR LOCAL FAST_FORWARD FOR
                    SELECT PkValue, RowJson
                    FROM dbo.MigrationScenarioRow
                    WHERE RunID = @SourceRunID
                      AND TableName = @Table
                    ORDER BY PkValue;

                DECLARE @OldPk BIGINT;
                DECLARE @RowJson NVARCHAR(MAX);

                IF OBJECT_ID('tempdb..#Inserted') IS NOT NULL DROP TABLE #Inserted;
                CREATE TABLE #Inserted (NewId BIGINT NOT NULL);

                OPEN row_cursor;
                FETCH NEXT FROM row_cursor INTO @OldPk, @RowJson;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    DECLARE @J NVARCHAR(MAX) = @RowJson;

                    DECLARE @PkFromCmfRecord BIT = 0;
                    IF @Table NOT LIKE N'SC\_%' ESCAPE N'\'
                       AND UPPER(@PkColumn) = UPPER(@Table) + N'RECORDID'
                       AND EXISTS (
                           SELECT 1
                           FROM #Rels r
                           WHERE r.ChildTable = @Table
                             AND r.ChildColumn = @PkColumn
                             AND r.ParentTable = N'CMFRECORD'
                       )
                    BEGIN
                        SET @PkFromCmfRecord = 1;
                    END

                    DECLARE @PkFromCmfCase BIT = 0;
                    IF UPPER(@PkColumn) = N'CASEID'
                       AND EXISTS (
                           SELECT 1
                           FROM #Rels r
                           WHERE r.ChildTable = @Table
                             AND r.ChildColumn = @PkColumn
                             AND r.ParentTable = N'CMFCASE'
                       )
                    BEGIN
                        SET @PkFromCmfCase = 1;
                    END

                    -- If PK is not identity, assign a fresh PK value now.
                    IF ISNULL(@PkIsIdentity, 0) = 0
                    BEGIN
                        DECLARE @AssignedPk BIGINT;

                        -- Special-case "record" tables: PK values come from CMFRECORD.ID.
                        -- If the PK column ends with RECORDID and we have already replayed CMFRECORD,
                        -- use the CMFRECORD mapping rather than MAX()+1.
                        IF @PkFromCmfRecord = 1
                        BEGIN
                            SELECT @AssignedPk = m.NewPkValue
                            FROM dbo.MigrationScenarioReplayMap m
                            WHERE m.ReplayRunID = @ReplayRunID
                              AND m.TableName = N'CMFRECORD'
                              AND m.OldPkValue = @OldPk;

                            IF @AssignedPk IS NULL
                                THROW 50000, N'Record table PK requires CMFRECORD mapping but none was found. Ensure CMFRECORD rows are captured and replayed first.', 1;
                        END

                        IF @PkFromCmfCase = 1
                        BEGIN
                            SELECT @AssignedPk = m.NewPkValue
                            FROM dbo.MigrationScenarioReplayMap m
                            WHERE m.ReplayRunID = @ReplayRunID
                              AND m.TableName = N'CMFCASE'
                              AND m.OldPkValue = @OldPk;

                            IF @AssignedPk IS NULL
                                THROW 50000, N'CASEID PK requires CMFCASE mapping but none was found. Ensure CMFCASE rows are captured and replayed first.', 1;
                        END

                        IF @AssignedPk IS NULL
                        BEGIN
                            SET @AssignedPk = @NextPk;
                            SET @NextPk = @NextPk + 1;
                        END

                        SET @J = JSON_MODIFY(@J, N'$.' + @PkColumn, @AssignedPk);
                    END

                    -- Apply FK remaps based on already-inserted parent rows
                    DECLARE @ChildCol SYSNAME;
                    DECLARE @ParentTable SYSNAME;
                    DECLARE @OldRef BIGINT;
                    DECLARE @NewRef BIGINT;

                    DECLARE rel_cursor CURSOR LOCAL FAST_FORWARD FOR
                        SELECT ParentTable, ChildColumn
                        FROM #Rels
                        WHERE ChildTable = @Table;

                    OPEN rel_cursor;
                    FETCH NEXT FROM rel_cursor INTO @ParentTable, @ChildCol;

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        IF @ChildCol = @PkColumn
                        BEGIN
                            FETCH NEXT FROM rel_cursor INTO @ParentTable, @ChildCol;
                            CONTINUE;
                        END

                        SET @OldRef = TRY_CONVERT(BIGINT, JSON_VALUE(@J, N'$.' + @ChildCol));
                        IF @OldRef IS NOT NULL
                        BEGIN
                            SET @NewRef = NULL;
                            SELECT @NewRef = m.NewPkValue
                            FROM dbo.MigrationScenarioReplayMap m
                            WHERE m.ReplayRunID = @ReplayRunID
                              AND m.TableName = @ParentTable
                              AND m.OldPkValue = @OldRef;

                            IF @NewRef IS NOT NULL
                                SET @J = JSON_MODIFY(@J, N'$.' + @ChildCol, @NewRef);
                        END

                        FETCH NEXT FROM rel_cursor INTO @ParentTable, @ChildCol;
                    END

                    CLOSE rel_cursor;
                    DEALLOCATE rel_cursor;

                    -- Apply name overrides
                    IF @Table = N'SC_PERSONREGISTRATION_INDIVIDUAL'
                    BEGIN
                        IF @First IS NOT NULL
                        BEGIN
                            SET @J = JSON_MODIFY(@J, N'$.FIRSTNAMES', @First);
                            SET @J = JSON_MODIFY(@J, N'$.SEARCHFIRSTNAMES', @First);
                        END

                        IF @Last IS NOT NULL
                        BEGIN
                            SET @J = JSON_MODIFY(@J, N'$.SURNAME', @Last);
                            SET @J = JSON_MODIFY(@J, N'$.SEARCHSURNAME', @Last);
                        END
                    END

                    IF @OverridesJson IS NOT NULL
                       AND ISJSON(@OverridesJson) = 1
                       AND JSON_QUERY(@OverridesJson, N'$.' + @Table) IS NOT NULL
                    BEGIN
                        DECLARE @OverrideObj NVARCHAR(MAX) = JSON_QUERY(@OverridesJson, N'$.' + @Table);
                        IF @OverrideObj IS NOT NULL
                        BEGIN
                            DECLARE @Ok SYSNAME;
                            DECLARE @Ov NVARCHAR(MAX);

                            DECLARE ov_cursor CURSOR LOCAL FAST_FORWARD FOR
                                SELECT [key], [value]
                                FROM OPENJSON(@OverrideObj);

                            OPEN ov_cursor;
                            FETCH NEXT FROM ov_cursor INTO @Ok, @Ov;

                            WHILE @@FETCH_STATUS = 0
                            BEGIN
                                IF LEFT(LTRIM(@Ov), 1) IN (N'{', N'[')
                                    SET @J = JSON_MODIFY(@J, N'$.' + @Ok, JSON_QUERY(@OverrideObj, N'$.' + @Ok));
                                ELSE
                                    SET @J = JSON_MODIFY(@J, N'$.' + @Ok, JSON_VALUE(@OverrideObj, N'$.' + @Ok));

                                FETCH NEXT FROM ov_cursor INTO @Ok, @Ov;
                            END

                            CLOSE ov_cursor;
                            DEALLOCATE ov_cursor;
                        END
                    END

                    DECLARE @Sql NVARCHAR(MAX) =
                        N'INSERT INTO dbo.' + QUOTENAME(@Table) + N' (' + @InsertCols + N') ' +
                        N'OUTPUT CONVERT(BIGINT, inserted.' + QUOTENAME(@PkColumn) + N') INTO #Inserted(NewId) ' +
                        N'SELECT ' + @SelectCols + N' FROM OPENJSON(@Json) WITH (' + @WithCols + N') AS src;';

                    DECLARE @NewPk BIGINT;

                    DELETE FROM #Inserted;
                    EXEC sp_executesql @Sql, N'@Json nvarchar(max)', @Json = @J;
                    SELECT TOP 1 @NewPk = NewId FROM #Inserted;

                    INSERT INTO dbo.MigrationScenarioReplayMap (ReplayRunID, TableName, OldPkValue, NewPkValue)
                    VALUES (@ReplayRunID, @Table, @OldPk, @NewPk);

                    FETCH NEXT FROM row_cursor INTO @OldPk, @RowJson;
                END

                CLOSE row_cursor;
                DEALLOCATE row_cursor;

                DROP TABLE #Inserted;

                FETCH NEXT FROM table_cursor INTO @Table;
            END

            CLOSE table_cursor;
            DEALLOCATE table_cursor;

            -- Ensure vw_Individual_List can see replayed individuals.
            -- That view is driven by SC_PERSONREGISTRATION_PROPERTIES (PE) keyed by CASEID.
            -- Our captured scenario may not include that table, so copy the properties row from the old case.
            IF EXISTS (SELECT 1 FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @ReplayRunID AND TableName = N'CMFCASE')
            BEGIN
                DECLARE @ColsInsert NVARCHAR(MAX);
                DECLARE @ColsSelect NVARCHAR(MAX);

                SELECT
                    @ColsInsert = STRING_AGG(QUOTENAME(c.name), N', ') WITHIN GROUP (ORDER BY c.column_id),
                    @ColsSelect = STRING_AGG(N'src.' + QUOTENAME(c.name), N', ') WITHIN GROUP (ORDER BY c.column_id)
                FROM sys.columns c
                WHERE c.object_id = OBJECT_ID(N'dbo.SC_PERSONREGISTRATION_PROPERTIES')
                  AND c.is_computed = 0
                  AND c.is_identity = 0
                  AND c.name <> N'CASEID';

                DECLARE @OldCaseId BIGINT;
                DECLARE @NewCaseId BIGINT;

                DECLARE case_cursor CURSOR LOCAL FAST_FORWARD FOR
                    SELECT OldPkValue, NewPkValue
                    FROM dbo.MigrationScenarioReplayMap
                    WHERE ReplayRunID = @ReplayRunID
                      AND TableName = N'CMFCASE';

                OPEN case_cursor;
                FETCH NEXT FROM case_cursor INTO @OldCaseId, @NewCaseId;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM dbo.SC_PERSONREGISTRATION_PROPERTIES p WHERE p.CASEID = @NewCaseId)
                       AND EXISTS (SELECT 1 FROM dbo.SC_PERSONREGISTRATION_PROPERTIES p WHERE p.CASEID = @OldCaseId)
                    BEGIN
                        DECLARE @SqlProps NVARCHAR(MAX) =
                            N'INSERT INTO dbo.SC_PERSONREGISTRATION_PROPERTIES (CASEID, ' + @ColsInsert + N') ' +
                            N'SELECT @NewCaseId, ' + @ColsSelect + N' ' +
                            N'FROM dbo.SC_PERSONREGISTRATION_PROPERTIES src ' +
                            N'WHERE src.CASEID = @OldCaseId;';

                        EXEC sp_executesql
                            @SqlProps,
                            N'@OldCaseId bigint, @NewCaseId bigint',
                            @OldCaseId = @OldCaseId,
                            @NewCaseId = @NewCaseId;

                        -- Align the properties record to the replayed individual name so it shows as expected in lists.
                        DECLARE @NewSurname NVARCHAR(510);
                        DECLARE @NewFirst NVARCHAR(120);

                        SELECT TOP 1
                            @NewSurname = i.SURNAME,
                            @NewFirst = i.FIRSTNAMES
                        FROM dbo.SC_PERSONREGISTRATION_INDIVIDUAL i
                        WHERE i.CASEID = @NewCaseId
                        ORDER BY i.INDIVIDUALRECORDID DESC;

                        IF @NewSurname IS NOT NULL OR @NewFirst IS NOT NULL
                        BEGIN
                            -- Only update columns if they exist.
                            IF COL_LENGTH(N'dbo.SC_PERSONREGISTRATION_PROPERTIES', N'SURNAME') IS NOT NULL
                                UPDATE dbo.SC_PERSONREGISTRATION_PROPERTIES SET SURNAME = @NewSurname WHERE CASEID = @NewCaseId;

                            IF COL_LENGTH(N'dbo.SC_PERSONREGISTRATION_PROPERTIES', N'FIRSTNAMES') IS NOT NULL
                                UPDATE dbo.SC_PERSONREGISTRATION_PROPERTIES SET FIRSTNAMES = @NewFirst WHERE CASEID = @NewCaseId;

                            IF COL_LENGTH(N'dbo.SC_PERSONREGISTRATION_PROPERTIES', N'FILENAME') IS NOT NULL
                                UPDATE dbo.SC_PERSONREGISTRATION_PROPERTIES
                                SET FILENAME = LTRIM(RTRIM(COALESCE(@NewSurname, N'') + CASE WHEN @NewSurname IS NOT NULL AND @NewFirst IS NOT NULL THEN N', ' ELSE N'' END + COALESCE(@NewFirst, N'')))
                                WHERE CASEID = @NewCaseId;
                        END

                        IF COL_LENGTH(N'dbo.SC_PERSONREGISTRATION_PROPERTIES', N'PERSONTYPE') IS NOT NULL
                            UPDATE dbo.SC_PERSONREGISTRATION_PROPERTIES SET PERSONTYPE = N'individual' WHERE CASEID = @NewCaseId;

                        IF COL_LENGTH(N'dbo.SC_PERSONREGISTRATION_PROPERTIES', N'DELETED') IS NOT NULL
                            UPDATE dbo.SC_PERSONREGISTRATION_PROPERTIES SET DELETED = 0 WHERE CASEID = @NewCaseId;
                    END

                    FETCH NEXT FROM case_cursor INTO @OldCaseId, @NewCaseId;
                END

                CLOSE case_cursor;
                DEALLOCATE case_cursor;
            END

            IF @ManageTransaction = 1
            BEGIN
                IF @Commit = 1
                    COMMIT TRANSACTION;
                ELSE
                    ROLLBACK TRANSACTION;
            END

            SELECT @ReplayRunID AS ReplayRunID, @i AS Iteration;
        END TRY
        BEGIN CATCH
            IF @ManageTransaction = 1 AND XACT_STATE() <> 0
                ROLLBACK TRANSACTION;
            THROW;
        END CATCH

        SET @i += 1;
    END
END
GO
