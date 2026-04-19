-- Check the CaseIDs of replayed CHANGES and MUTATION
DECLARE @ReplayRunID UNIQUEIDENTIFIER;
SELECT TOP 1 @ReplayRunID = ReplayRunID
FROM dbo.MigrationScenarioReplayRun
ORDER BY ReplayRunID DESC;

-- Get replayed individual CaseIDs
SELECT 'Replayed Individual Cases' AS Source, i.CASEID
FROM SC_PERSONREGISTRATION_INDIVIDUAL i
WHERE i.INDIVIDUALRECORDID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID
      AND TableName = 'SC_PERSONREGISTRATION_INDIVIDUAL'
);

-- Get replayed CHANGES CaseIDs
PRINT '';
PRINT '=== Replayed CHANGES CaseIDs ===';
SELECT 
    c.CHANGESRECORDID,
    c.CASEID,
    c.CHANGERECORDID,
    c.TOPICOFCHANGE,
    CASE WHEN i.CASEID IS NOT NULL THEN 'MATCHES INDIVIDUAL CASE' ELSE 'WRONG CASE' END AS Status
FROM CHANGES c
LEFT JOIN SC_PERSONREGISTRATION_INDIVIDUAL i ON i.CASEID = c.CASEID
WHERE c.CHANGESRECORDID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID
      AND TableName = 'CHANGES'
);

-- Get replayed MUTATION CaseIDs
PRINT '';
PRINT '=== Replayed MUTATION CaseIDs ===';
SELECT 
    m.MUTATIONRECORDID,
    m.CASEID,
    CASE WHEN i.CASEID IS NOT NULL THEN 'MATCHES INDIVIDUAL CASE' ELSE 'WRONG CASE' END AS Status
FROM MUTATION m
LEFT JOIN SC_PERSONREGISTRATION_INDIVIDUAL i ON i.CASEID = m.CASEID
WHERE m.MUTATIONRECORDID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID
      AND TableName = 'MUTATION'
);

-- Check what the captured CHANGES CASEID was
PRINT '';
PRINT '=== Original Captured CHANGES CASEID ===';
SELECT TOP 1
    JSON_VALUE(RowJson, '$.CASEID') AS OriginalCaseID
FROM dbo.MigrationScenarioRow
WHERE TableName = 'CHANGES';
