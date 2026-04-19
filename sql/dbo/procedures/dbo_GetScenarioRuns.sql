SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.GetScenarioRuns
    @ScenarioID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT RunID, ScenarioID, StartedAt, EndedAt, SnapshotID, Notes
    FROM dbo.MigrationScenarioRun
    WHERE ScenarioID = @ScenarioID
    ORDER BY StartedAt DESC;
END
GO
