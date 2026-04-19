-- Test the replay fix by running a single replay with commit

DECLARE @RunID UNIQUEIDENTIFIER;
SELECT TOP 1 @RunID = RunID
FROM dbo.MigrationScenarioRun
WHERE EndedAt IS NOT NULL
ORDER BY StartedAt DESC;

PRINT 'Source RunID: ' + CAST(@RunID AS NVARCHAR(50));

-- Run a single replay with commit
EXEC dbo.ReplayScenarioRun 
    @SourceRunID = @RunID,
    @Times = 1,
    @Commit = 1;
