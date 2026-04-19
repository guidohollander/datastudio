SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.StartMigrationScenarioRun
    @ScenarioName NVARCHAR(200),
    @Notes NVARCHAR(1000) = NULL,
    @RunID UNIQUEIDENTIFIER = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ScenarioID INT;
    SELECT @ScenarioID = ScenarioID
    FROM dbo.MigrationScenario
    WHERE Name = @ScenarioName;

    IF @ScenarioID IS NULL
    BEGIN
        INSERT INTO dbo.MigrationScenario (Name, Notes)
        VALUES (@ScenarioName, @Notes);

        SET @ScenarioID = CAST(SCOPE_IDENTITY() AS INT);
    END

    IF @RunID IS NULL
        SET @RunID = NEWID();

    DECLARE @SnapshotID UNIQUEIDENTIFIER;

    INSERT INTO dbo.MigrationScenarioRun (RunID, ScenarioID, Notes)
    VALUES (@RunID, @ScenarioID, @Notes);

    EXEC dbo.TakeDatabaseSnapshot @SnapshotID = @SnapshotID OUTPUT;

    UPDATE dbo.MigrationScenarioRun
    SET SnapshotID = @SnapshotID
    WHERE RunID = @RunID;

    EXEC dbo.UpdateIdentitySnapshot;

    DELETE FROM dbo.MigrationScenarioIdentityBaseline
    WHERE RunID = @RunID;

    INSERT INTO dbo.MigrationScenarioIdentityBaseline (RunID, TableName, IdentityColumn, LastIdentityValue)
    SELECT @RunID, TableName, IdentityColumn, LastIdentityValue
    FROM dbo.IdentitySnapshot;

    -- Auto-create global baseline if it doesn't exist (first-time setup)
    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationGlobalBaseline)
    BEGIN
        PRINT 'Global baseline is empty. Creating baseline automatically...';
        PRINT 'This is a one-time operation that may take several minutes.';
        EXEC dbo.RefreshGlobalBaseline;
        PRINT 'Global baseline created successfully.';
    END

    SELECT @RunID AS RunID, @ScenarioID AS ScenarioID, @SnapshotID AS SnapshotID;
END
GO
