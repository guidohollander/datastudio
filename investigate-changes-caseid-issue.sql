-- Investigate why CHANGES.CASEID doesn't match the replayed case

DECLARE @ReplayRunID UNIQUEIDENTIFIER;
SELECT TOP 1 @ReplayRunID = ReplayRunID
FROM dbo.MigrationScenarioReplayRun
ORDER BY CreatedAt DESC;

PRINT '=== Replayed Case ===';
SELECT 
    CAST(NewPkValue AS BIGINT) AS NewCaseID,
    CAST(OldPkValue AS BIGINT) AS OldCaseID
FROM dbo.MigrationScenarioReplayMap
WHERE ReplayRunID = @ReplayRunID 
  AND TableName = 'SC_PERSONREGISTRATION_PROPERTIES';

PRINT '';
PRINT '=== Replayed CHANGES and their CASEID ===';
SELECT 
    ch.CHANGESRECORDID,
    ch.CASEID AS ChangesCaseID,
    map.OldPkValue AS OldChangesID,
    map.NewPkValue AS NewChangesID
FROM CHANGES ch
INNER JOIN dbo.MigrationScenarioReplayMap map ON CAST(map.NewPkValue AS BIGINT) = ch.CHANGESRECORDID
WHERE map.ReplayRunID = @ReplayRunID 
  AND map.TableName = 'CHANGES';

PRINT '';
PRINT '=== Original CHANGES and their CASEID ===';
DECLARE @OriginalRunID UNIQUEIDENTIFIER;
SELECT TOP 1 @OriginalRunID = RunID
FROM dbo.MigrationScenarioRun
WHERE EndedAt IS NOT NULL
ORDER BY StartedAt DESC;

SELECT 
    ch.CHANGESRECORDID,
    ch.CASEID AS OriginalCaseID
FROM CHANGES ch
WHERE ch.CHANGESRECORDID IN (
    SELECT CAST(PkValue AS BIGINT) FROM dbo.MigrationScenarioRow
    WHERE RunID = @OriginalRunID AND TableName = 'CHANGES'
);

PRINT '';
PRINT '=== CASEID Mapping ===';
SELECT 
    'Original CASEID' AS Label,
    CAST(OldPkValue AS BIGINT) AS CaseID
FROM dbo.MigrationScenarioReplayMap
WHERE ReplayRunID = @ReplayRunID 
  AND TableName = 'SC_PERSONREGISTRATION_PROPERTIES'
UNION ALL
SELECT 
    'Replayed CASEID' AS Label,
    CAST(NewPkValue AS BIGINT) AS CaseID
FROM dbo.MigrationScenarioReplayMap
WHERE ReplayRunID = @ReplayRunID 
  AND TableName = 'SC_PERSONREGISTRATION_PROPERTIES'
UNION ALL
SELECT 
    'CHANGES.CASEID (should match Replayed)' AS Label,
    ch.CASEID
FROM CHANGES ch
WHERE ch.CHANGESRECORDID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'CHANGES'
)
GROUP BY ch.CASEID;

PRINT '';
PRINT '=== Diagnosis ===';
PRINT 'If CHANGES.CASEID does not match the Replayed CASEID, then CASEID was not remapped correctly!';
