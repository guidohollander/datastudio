SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.ResetFramework
    @PreserveRunID UNIQUEIDENTIFIER = NULL,
    @DryRun BIT = 1,
    @Commit BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Commit = 1 AND @DryRun = 1
        THROW 50000, N'Invalid parameters: @Commit=1 requires @DryRun=0.', 1;

    DECLARE @PreserveScenarioID INT = NULL;

    IF @PreserveRunID IS NOT NULL
    BEGIN
        SELECT @PreserveScenarioID = ScenarioID
        FROM dbo.MigrationScenarioRun
        WHERE RunID = @PreserveRunID;

        IF @PreserveScenarioID IS NULL
            THROW 50000, N'@PreserveRunID not found in dbo.MigrationScenarioRun.', 1;
    END

    IF @DryRun = 1
    BEGIN
        IF OBJECT_ID('tempdb..#Counts') IS NOT NULL DROP TABLE #Counts;
        CREATE TABLE #Counts (TableName SYSNAME NOT NULL, Cnt BIGINT NOT NULL);

        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.DataDictionaryColumn', COUNT(*) FROM dbo.DataDictionaryColumn;
        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.DataDictionaryIndex', COUNT(*) FROM dbo.DataDictionaryIndex;
        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.DataDictionaryIndexColumn', COUNT(*) FROM dbo.DataDictionaryIndexColumn;
        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.DataDictionaryRelationshipCandidate', COUNT(*) FROM dbo.DataDictionaryRelationshipCandidate;
        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.DataDictionaryTable', COUNT(*) FROM dbo.DataDictionaryTable;

        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.MigrationScenario', COUNT(*) FROM dbo.MigrationScenario;
        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.MigrationScenarioIdentityBaseline', COUNT(*) FROM dbo.MigrationScenarioIdentityBaseline;
        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.MigrationScenarioNewRows', COUNT(*) FROM dbo.MigrationScenarioNewRows;
        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.MigrationScenarioRelationship', COUNT(*) FROM dbo.MigrationScenarioRelationship;
        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.MigrationScenarioReplayMap', COUNT(*) FROM dbo.MigrationScenarioReplayMap;
        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.MigrationScenarioReplayRun', COUNT(*) FROM dbo.MigrationScenarioReplayRun;
        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.MigrationScenarioRow', COUNT(*) FROM dbo.MigrationScenarioRow;
        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.MigrationScenarioRun', COUNT(*) FROM dbo.MigrationScenarioRun;
        INSERT INTO #Counts(TableName, Cnt) SELECT N'dbo.MigrationTableRelationships', COUNT(*) FROM dbo.MigrationTableRelationships;

        SELECT TableName, Cnt
        FROM #Counts
        ORDER BY TableName;

        SELECT
            @PreserveRunID AS PreserveRunID,
            @PreserveScenarioID AS PreserveScenarioID;

        SELECT
            (SELECT COUNT(*) FROM dbo.MigrationScenarioRow WHERE @PreserveRunID IS NULL OR RunID <> @PreserveRunID) AS RowsToDelete_MigrationScenarioRow,
            (SELECT COUNT(*) FROM dbo.MigrationScenarioRun WHERE @PreserveRunID IS NULL OR RunID <> @PreserveRunID) AS RowsToDelete_MigrationScenarioRun,
            (SELECT COUNT(*) FROM dbo.MigrationScenario WHERE @PreserveScenarioID IS NULL OR ScenarioID <> @PreserveScenarioID) AS RowsToDelete_MigrationScenario;

        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ReplayRunID UNIQUEIDENTIFIER;
        DECLARE replay_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT ReplayRunID
            FROM dbo.MigrationScenarioReplayRun
            ORDER BY CreatedAt DESC;

        OPEN replay_cursor;
        FETCH NEXT FROM replay_cursor INTO @ReplayRunID;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.CleanupScenarioReplayRun @ReplayRunID = @ReplayRunID;
            FETCH NEXT FROM replay_cursor INTO @ReplayRunID;
        END

        CLOSE replay_cursor;
        DEALLOCATE replay_cursor;

        DELETE FROM dbo.MigrationScenarioReplayMap;
        DELETE FROM dbo.MigrationScenarioReplayRun;

        DELETE FROM dbo.MigrationScenarioRelationship WHERE @PreserveRunID IS NULL OR RunID <> @PreserveRunID;
        DELETE FROM dbo.MigrationScenarioNewRows WHERE @PreserveRunID IS NULL OR RunID <> @PreserveRunID;
        DELETE FROM dbo.MigrationScenarioIdentityBaseline WHERE @PreserveRunID IS NULL OR RunID <> @PreserveRunID;

        DELETE FROM dbo.MigrationScenarioRow WHERE @PreserveRunID IS NULL OR RunID <> @PreserveRunID;
        DELETE FROM dbo.MigrationScenarioRun WHERE @PreserveRunID IS NULL OR RunID <> @PreserveRunID;
        DELETE FROM dbo.MigrationScenario WHERE @PreserveScenarioID IS NULL OR ScenarioID <> @PreserveScenarioID;

        DELETE FROM dbo.MigrationTableRelationships;

        DELETE FROM dbo.DataDictionaryRelationshipCandidate;
        DELETE FROM dbo.DataDictionaryIndexColumn;
        DELETE FROM dbo.DataDictionaryIndex;
        DELETE FROM dbo.DataDictionaryColumn;
        DELETE FROM dbo.DataDictionaryTable;

        COMMIT TRANSACTION;

        SELECT
            @PreserveRunID AS PreserveRunID,
            @PreserveScenarioID AS PreserveScenarioID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
