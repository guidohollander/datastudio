SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.CaptureScenarioRelationships
    @RunID UNIQUEIDENTIFIER,
    @Source NVARCHAR(100) = NULL,
    @Notes NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationScenarioRun WHERE RunID = @RunID)
        THROW 50000, N'Unknown RunID.', 1;

    INSERT INTO dbo.MigrationScenarioRelationship (RunID, RelationshipID, Notes)
    SELECT
        @RunID,
        r.RelationshipID,
        @Notes
    FROM dbo.MigrationTableRelationships r
    WHERE r.IsActive = 1
      AND (@Source IS NULL OR r.Source = @Source)
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.MigrationScenarioRelationship x
            WHERE x.RunID = @RunID AND x.RelationshipID = r.RelationshipID
      );

    SELECT msr.RunID, msr.RelationshipID, msr.AddedAt, msr.Notes
    FROM dbo.MigrationScenarioRelationship msr
    WHERE msr.RunID = @RunID
    ORDER BY msr.AddedAt, msr.RelationshipID;
END
GO
