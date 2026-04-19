SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.CaptureScenarioRowDetails
    @RunID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationScenarioRun WHERE RunID = @RunID)
        THROW 50000, N'Unknown RunID.', 1;

    DELETE FROM dbo.MigrationScenarioRow
    WHERE RunID = @RunID;

    DECLARE @table SYSNAME, @pkCol SYSNAME, @sql NVARCHAR(MAX);

    DECLARE cur CURSOR FOR
    SELECT DISTINCT TableName
    FROM dbo.MigrationScenarioNewRows
    WHERE RunID = @RunID;

    OPEN cur;
    FETCH NEXT FROM cur INTO @table;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @pkCol = NULL;

        SELECT @pkCol = IdentityColumn
        FROM dbo.IdentitySnapshot
        WHERE TableName = @table;

        IF @pkCol IS NULL
        BEGIN
            SELECT TOP 1 @pkCol = c.COLUMN_NAME
            FROM INFORMATION_SCHEMA.COLUMNS c
            WHERE c.TABLE_SCHEMA = 'dbo'
              AND c.TABLE_NAME = @table
              AND COLUMNPROPERTY(OBJECT_ID('dbo.' + @table), c.COLUMN_NAME, 'IsIdentity') = 1;
        END

        IF @pkCol IS NOT NULL
        BEGIN
            SET @sql = N'
            INSERT INTO dbo.MigrationScenarioRow (RunID, TableName, PkColumn, PkValue, RowJson)
            SELECT
                @RunID,
                @TableName,
                @PkColumn,
                CAST(t.' + QUOTENAME(@pkCol) + N' AS BIGINT) AS PkValue,
                (SELECT t.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS RowJson
            FROM dbo.' + QUOTENAME(@table) + N' t
            INNER JOIN dbo.MigrationScenarioNewRows n
                ON n.RunID = @RunID
               AND n.TableName = @TableName
               AND n.NewIdentityValue = CAST(t.' + QUOTENAME(@pkCol) + N' AS BIGINT)
            ORDER BY CAST(t.' + QUOTENAME(@pkCol) + N' AS BIGINT);';

            BEGIN TRY
                EXEC sp_executesql
                    @sql,
                    N'@RunID UNIQUEIDENTIFIER, @TableName SYSNAME, @PkColumn SYSNAME',
                    @RunID = @RunID,
                    @TableName = @table,
                    @PkColumn = @pkCol;
            END TRY
            BEGIN CATCH
                DECLARE @err NVARCHAR(2048) = ERROR_MESSAGE();
                DECLARE @ctx NVARCHAR(256) = N'dbo.' + @table;
                DECLARE @msg NVARCHAR(2048) = N'dbo.CaptureScenarioRowDetails failed for ' + @ctx + N': ' + @err;
                THROW 50000, @msg, 1;
            END CATCH
        END

        FETCH NEXT FROM cur INTO @table;
    END

    CLOSE cur;
    DEALLOCATE cur;

    IF OBJECT_ID(N'dbo.SC_PERSONREGISTRATION_PROPERTIES', N'U') IS NOT NULL
       AND COL_LENGTH(N'dbo.SC_PERSONREGISTRATION_PROPERTIES', N'CASEID') IS NOT NULL
    BEGIN
        INSERT INTO dbo.MigrationScenarioRow (RunID, TableName, PkColumn, PkValue, RowJson)
        SELECT
            @RunID,
            N'SC_PERSONREGISTRATION_PROPERTIES',
            N'CASEID',
            c.PkValue,
            (SELECT p.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS RowJson
        FROM dbo.MigrationScenarioRow c
        JOIN dbo.SC_PERSONREGISTRATION_PROPERTIES p
          ON p.CASEID = c.PkValue
        WHERE c.RunID = @RunID
          AND c.TableName = N'CMFCASE'
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.MigrationScenarioRow x
              WHERE x.RunID = @RunID
                AND x.TableName = N'SC_PERSONREGISTRATION_PROPERTIES'
                AND x.PkValue = c.PkValue
          );
    END

    IF OBJECT_ID('tempdb..#CaseIds') IS NOT NULL DROP TABLE #CaseIds;
    CREATE TABLE #CaseIds (CaseId BIGINT NOT NULL PRIMARY KEY);

    INSERT INTO #CaseIds(CaseId)
    SELECT DISTINCT r.PkValue
    FROM dbo.MigrationScenarioRow r
    WHERE r.RunID = @RunID
      AND r.TableName = N'CMFCASE';

    IF OBJECT_ID('tempdb..#MutationIds') IS NOT NULL DROP TABLE #MutationIds;
    CREATE TABLE #MutationIds (MutationRecordId BIGINT NOT NULL PRIMARY KEY);

    DECLARE @Pk SYSNAME;

    -- Capture MUTATION rows for captured cases (vw_Caseheader_Individual, vw_SC_PersonRegistration_Individual)
    IF OBJECT_ID(N'dbo.MUTATION', N'U') IS NOT NULL
       AND EXISTS (SELECT 1 FROM #CaseIds)
       AND COL_LENGTH(N'dbo.MUTATION', N'CASEID') IS NOT NULL
    BEGIN
        SELECT @Pk = NULL;
        SELECT TOP 1 @Pk = c.ColumnName
        FROM dbo.DataDictionaryColumn c
        JOIN dbo.DataDictionaryTable t ON t.TableObjectId = c.TableObjectId
        WHERE t.SchemaName = N'dbo' AND t.TableName = N'MUTATION' AND c.IsPrimaryKey = 1
        ORDER BY c.ColumnId;

        IF @Pk IS NOT NULL
        BEGIN
            DECLARE @SqlMutation NVARCHAR(MAX) = N'
            INSERT INTO dbo.MigrationScenarioRow (RunID, TableName, PkColumn, PkValue, RowJson)
            SELECT
                @RunID,
                N''MUTATION'',
                @PkColumn,
                CAST(m.' + QUOTENAME(@Pk) + N' AS BIGINT) AS PkValue,
                (SELECT m.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS RowJson
            FROM dbo.MUTATION m
            JOIN #CaseIds c ON c.CaseId = TRY_CONVERT(BIGINT, m.CASEID)
            WHERE m.DELETED = 0
              AND NOT EXISTS (
                  SELECT 1
                  FROM dbo.MigrationScenarioRow x
                  WHERE x.RunID = @RunID
                    AND x.TableName = N''MUTATION''
                    AND x.PkValue = CAST(m.' + QUOTENAME(@Pk) + N' AS BIGINT)
              );

            INSERT INTO #MutationIds(MutationRecordId)
            SELECT DISTINCT CAST(m.' + QUOTENAME(@Pk) + N' AS BIGINT)
            FROM dbo.MUTATION m
            JOIN #CaseIds c ON c.CaseId = TRY_CONVERT(BIGINT, m.CASEID)
            WHERE m.DELETED = 0;
            ';

            EXEC sp_executesql
                @SqlMutation,
                N'@RunID uniqueidentifier, @PkColumn sysname',
                @RunID = @RunID,
                @PkColumn = @Pk;
        END
    END

    -- Capture CHANGES rows for captured mutations (vw_SC_PersonRegistration_Individual)
    IF OBJECT_ID(N'dbo.CHANGES', N'U') IS NOT NULL
       AND EXISTS (SELECT 1 FROM #MutationIds)
       AND COL_LENGTH(N'dbo.CHANGES', N'MUTATIONRECORDID') IS NOT NULL
    BEGIN
        SELECT @Pk = NULL;
        SELECT TOP 1 @Pk = c.ColumnName
        FROM dbo.DataDictionaryColumn c
        JOIN dbo.DataDictionaryTable t ON t.TableObjectId = c.TableObjectId
        WHERE t.SchemaName = N'dbo' AND t.TableName = N'CHANGES' AND c.IsPrimaryKey = 1
        ORDER BY c.ColumnId;

        IF @Pk IS NOT NULL
        BEGIN
            DECLARE @SqlChanges NVARCHAR(MAX) = N'
            INSERT INTO dbo.MigrationScenarioRow (RunID, TableName, PkColumn, PkValue, RowJson)
            SELECT
                @RunID,
                N''CHANGES'',
                @PkColumn,
                CAST(ch.' + QUOTENAME(@Pk) + N' AS BIGINT) AS PkValue,
                (SELECT ch.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS RowJson
            FROM dbo.CHANGES ch
            JOIN #MutationIds m ON m.MutationRecordId = TRY_CONVERT(BIGINT, ch.MUTATIONRECORDID)
            WHERE ch.DELETED = 0
              AND NOT EXISTS (
                  SELECT 1
                  FROM dbo.MigrationScenarioRow x
                  WHERE x.RunID = @RunID
                    AND x.TableName = N''CHANGES''
                    AND x.PkValue = CAST(ch.' + QUOTENAME(@Pk) + N' AS BIGINT)
              );
            ';

            EXEC sp_executesql
                @SqlChanges,
                N'@RunID uniqueidentifier, @PkColumn sysname',
                @RunID = @RunID,
                @PkColumn = @Pk;
        END
    END

    -- Capture SC_ACCOUNT rows for captured cases (vw_Caseheader_Individual)
    IF OBJECT_ID(N'dbo.SC_ACCOUNT', N'U') IS NOT NULL
       AND EXISTS (SELECT 1 FROM #CaseIds)
       AND COL_LENGTH(N'dbo.SC_ACCOUNT', N'PERSONID') IS NOT NULL
    BEGIN
        SELECT @Pk = NULL;
        SELECT TOP 1 @Pk = c.ColumnName
        FROM dbo.DataDictionaryColumn c
        JOIN dbo.DataDictionaryTable t ON t.TableObjectId = c.TableObjectId
        WHERE t.SchemaName = N'dbo' AND t.TableName = N'SC_ACCOUNT' AND c.IsPrimaryKey = 1
        ORDER BY c.ColumnId;

        IF @Pk IS NOT NULL
        BEGIN
            DECLARE @SqlAccount NVARCHAR(MAX) = N'
            INSERT INTO dbo.MigrationScenarioRow (RunID, TableName, PkColumn, PkValue, RowJson)
            SELECT
                @RunID,
                N''SC_ACCOUNT'',
                @PkColumn,
                CAST(a.' + QUOTENAME(@Pk) + N' AS BIGINT) AS PkValue,
                (SELECT a.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS RowJson
            FROM dbo.SC_ACCOUNT a
            JOIN #CaseIds c ON c.CaseId = TRY_CONVERT(BIGINT, a.PERSONID)
            WHERE a.DELETED = 0
              AND NOT EXISTS (
                  SELECT 1
                  FROM dbo.MigrationScenarioRow x
                  WHERE x.RunID = @RunID
                    AND x.TableName = N''SC_ACCOUNT''
                    AND x.PkValue = CAST(a.' + QUOTENAME(@Pk) + N' AS BIGINT)
              );
            ';

            EXEC sp_executesql
                @SqlAccount,
                N'@RunID uniqueidentifier, @PkColumn sysname',
                @RunID = @RunID,
                @PkColumn = @Pk;
        END
    END

    -- Capture SC_PERSONREGISTRATION_RELATION rows (vw_Caseheader_Individual)
    IF OBJECT_ID(N'dbo.SC_PERSONREGISTRATION_RELATION', N'U') IS NOT NULL
       AND EXISTS (SELECT 1 FROM #CaseIds)
       AND COL_LENGTH(N'dbo.SC_PERSONREGISTRATION_RELATION', N'CASEID') IS NOT NULL
       AND COL_LENGTH(N'dbo.SC_PERSONREGISTRATION_RELATION', N'RELATIONCASEID') IS NOT NULL
    BEGIN
        SELECT @Pk = NULL;
        SELECT TOP 1 @Pk = c.ColumnName
        FROM dbo.DataDictionaryColumn c
        JOIN dbo.DataDictionaryTable t ON t.TableObjectId = c.TableObjectId
        WHERE t.SchemaName = N'dbo' AND t.TableName = N'SC_PERSONREGISTRATION_RELATION' AND c.IsPrimaryKey = 1
        ORDER BY c.ColumnId;

        IF @Pk IS NOT NULL
        BEGIN
            DECLARE @SqlRel NVARCHAR(MAX) = N'
            INSERT INTO dbo.MigrationScenarioRow (RunID, TableName, PkColumn, PkValue, RowJson)
            SELECT
                @RunID,
                N''SC_PERSONREGISTRATION_RELATION'',
                @PkColumn,
                CAST(r.' + QUOTENAME(@Pk) + N' AS BIGINT) AS PkValue,
                (SELECT r.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS RowJson
            FROM dbo.SC_PERSONREGISTRATION_RELATION r
            WHERE r.DELETED = 0
              AND (
                    EXISTS (SELECT 1 FROM #CaseIds c WHERE c.CaseId = TRY_CONVERT(BIGINT, r.CASEID))
                 OR EXISTS (SELECT 1 FROM #CaseIds c WHERE c.CaseId = TRY_CONVERT(BIGINT, r.RELATIONCASEID))
              )
              AND NOT EXISTS (
                  SELECT 1
                  FROM dbo.MigrationScenarioRow x
                  WHERE x.RunID = @RunID
                    AND x.TableName = N''SC_PERSONREGISTRATION_RELATION''
                    AND x.PkValue = CAST(r.' + QUOTENAME(@Pk) + N' AS BIGINT)
              );
            ';

            EXEC sp_executesql
                @SqlRel,
                N'@RunID uniqueidentifier, @PkColumn sysname',
                @RunID = @RunID,
                @PkColumn = @Pk;
        END
    END

    -- Capture enterprise/dissolution sidecars (vw_Caseheader_Individual)
    IF OBJECT_ID(N'dbo.SC_PERSONREGISTRATION_ENTERPRISE', N'U') IS NOT NULL
       AND EXISTS (SELECT 1 FROM #CaseIds)
       AND COL_LENGTH(N'dbo.SC_PERSONREGISTRATION_ENTERPRISE', N'CASEID') IS NOT NULL
    BEGIN
        SELECT @Pk = NULL;
        SELECT TOP 1 @Pk = c.ColumnName
        FROM dbo.DataDictionaryColumn c
        JOIN dbo.DataDictionaryTable t ON t.TableObjectId = c.TableObjectId
        WHERE t.SchemaName = N'dbo' AND t.TableName = N'SC_PERSONREGISTRATION_ENTERPRISE' AND c.IsPrimaryKey = 1
        ORDER BY c.ColumnId;

        IF @Pk IS NOT NULL
        BEGIN
            DECLARE @SqlEnt NVARCHAR(MAX) = N'
            INSERT INTO dbo.MigrationScenarioRow (RunID, TableName, PkColumn, PkValue, RowJson)
            SELECT
                @RunID,
                N''SC_PERSONREGISTRATION_ENTERPRISE'',
                @PkColumn,
                CAST(e.' + QUOTENAME(@Pk) + N' AS BIGINT) AS PkValue,
                (SELECT e.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS RowJson
            FROM dbo.SC_PERSONREGISTRATION_ENTERPRISE e
            JOIN #CaseIds c ON c.CaseId = TRY_CONVERT(BIGINT, e.CASEID)
            WHERE e.DELETED = 0
              AND NOT EXISTS (
                  SELECT 1
                  FROM dbo.MigrationScenarioRow x
                  WHERE x.RunID = @RunID
                    AND x.TableName = N''SC_PERSONREGISTRATION_ENTERPRISE''
                    AND x.PkValue = CAST(e.' + QUOTENAME(@Pk) + N' AS BIGINT)
              );
            ';

            EXEC sp_executesql
                @SqlEnt,
                N'@RunID uniqueidentifier, @PkColumn sysname',
                @RunID = @RunID,
                @PkColumn = @Pk;
        END
    END

    IF OBJECT_ID(N'dbo.SC_PERSONREGISTRATION_DISSOLUTION', N'U') IS NOT NULL
       AND EXISTS (SELECT 1 FROM #CaseIds)
       AND COL_LENGTH(N'dbo.SC_PERSONREGISTRATION_DISSOLUTION', N'CASEID') IS NOT NULL
    BEGIN
        SELECT @Pk = NULL;
        SELECT TOP 1 @Pk = c.ColumnName
        FROM dbo.DataDictionaryColumn c
        JOIN dbo.DataDictionaryTable t ON t.TableObjectId = c.TableObjectId
        WHERE t.SchemaName = N'dbo' AND t.TableName = N'SC_PERSONREGISTRATION_DISSOLUTION' AND c.IsPrimaryKey = 1
        ORDER BY c.ColumnId;

        IF @Pk IS NOT NULL
        BEGIN
            DECLARE @SqlDis NVARCHAR(MAX) = N'
            INSERT INTO dbo.MigrationScenarioRow (RunID, TableName, PkColumn, PkValue, RowJson)
            SELECT
                @RunID,
                N''SC_PERSONREGISTRATION_DISSOLUTION'',
                @PkColumn,
                CAST(d.' + QUOTENAME(@Pk) + N' AS BIGINT) AS PkValue,
                (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS RowJson
            FROM dbo.SC_PERSONREGISTRATION_DISSOLUTION d
            JOIN #CaseIds c ON c.CaseId = TRY_CONVERT(BIGINT, d.CASEID)
            WHERE d.DELETED = 0
              AND NOT EXISTS (
                  SELECT 1
                  FROM dbo.MigrationScenarioRow x
                  WHERE x.RunID = @RunID
                    AND x.TableName = N''SC_PERSONREGISTRATION_DISSOLUTION''
                    AND x.PkValue = CAST(d.' + QUOTENAME(@Pk) + N' AS BIGINT)
              );
            ';

            EXEC sp_executesql
                @SqlDis,
                N'@RunID uniqueidentifier, @PkColumn sysname',
                @RunID = @RunID,
                @PkColumn = @Pk;
        END
    END

    IF OBJECT_ID(N'dbo.CMFRECORD', N'U') IS NOT NULL
    BEGIN
        IF OBJECT_ID('tempdb..#RecordIds') IS NOT NULL DROP TABLE #RecordIds;
        CREATE TABLE #RecordIds (RecordId BIGINT NOT NULL PRIMARY KEY);

        INSERT INTO #RecordIds(RecordId)
        SELECT DISTINCT TRY_CONVERT(BIGINT, j.[value])
        FROM dbo.MigrationScenarioRow r
        CROSS APPLY OPENJSON(r.RowJson) j
        WHERE r.RunID = @RunID
          AND j.[type] IN (1,2)
          AND j.[key] LIKE N'%RECORDID'
          AND TRY_CONVERT(BIGINT, j.[value]) IS NOT NULL;

        INSERT INTO dbo.MigrationScenarioRow (RunID, TableName, PkColumn, PkValue, RowJson)
        SELECT
            @RunID,
            N'CMFRECORD',
            N'ID',
            rid.RecordId,
            (SELECT cr.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS RowJson
        FROM #RecordIds rid
        JOIN dbo.CMFRECORD cr
          ON cr.ID = rid.RecordId
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.MigrationScenarioRow x
            WHERE x.RunID = @RunID
              AND x.TableName = N'CMFRECORD'
              AND x.PkValue = rid.RecordId
        );

        DROP TABLE #RecordIds;
    END

    DROP TABLE #MutationIds;
    DROP TABLE #CaseIds;

    SELECT RunID, TableName, PkColumn, PkValue, CapturedAt, RowJson
    FROM dbo.MigrationScenarioRow
    WHERE RunID = @RunID
    ORDER BY TableName, PkValue;
END
GO
