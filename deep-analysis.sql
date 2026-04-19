-- Deep analysis of latest replay vs original data

DECLARE @ReplayRunID UNIQUEIDENTIFIER;
SELECT TOP 1 @ReplayRunID = ReplayRunID
FROM dbo.MigrationScenarioReplayRun
ORDER BY CreatedAt DESC;

DECLARE @OrigRunID UNIQUEIDENTIFIER;
SELECT TOP 1 @OrigRunID = RunID
FROM dbo.MigrationScenarioRun
WHERE EndedAt IS NOT NULL
ORDER BY StartedAt DESC;

PRINT '=== Replay Run: ' + CAST(@ReplayRunID AS NVARCHAR(50));
PRINT '=== Original Run: ' + CAST(@OrigRunID AS NVARCHAR(50));

-- 1. What tables were replayed?
PRINT '';
PRINT '=== 1. Tables replayed ===';
SELECT TableName, COUNT(*) AS Cnt
FROM dbo.MigrationScenarioReplayMap
WHERE ReplayRunID = @ReplayRunID
GROUP BY TableName
ORDER BY TableName;

-- 2. What tables were captured?
PRINT '';
PRINT '=== 2. Tables captured ===';
SELECT TableName, COUNT(*) AS Cnt
FROM dbo.MigrationScenarioRow
WHERE RunID = @OrigRunID
GROUP BY TableName
ORDER BY TableName;

-- 3. Replayed case
PRINT '';
PRINT '=== 3. Replayed case ===';
SELECT 
    m.TableName,
    CAST(m.OldPkValue AS BIGINT) AS OldID,
    CAST(m.NewPkValue AS BIGINT) AS NewID
FROM dbo.MigrationScenarioReplayMap m
WHERE m.ReplayRunID = @ReplayRunID
  AND m.TableName = 'SC_PERSONREGISTRATION_PROPERTIES';

-- 4. Replayed CHANGES - do they point to the new case?
PRINT '';
PRINT '=== 4. Replayed CHANGES ===';
SELECT 
    ch.CHANGESRECORDID,
    ch.CASEID AS ChangesCaseID,
    (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @ReplayRunID AND TableName = 'SC_PERSONREGISTRATION_PROPERTIES') AS ExpectedCaseID,
    CASE WHEN ch.CASEID = (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @ReplayRunID AND TableName = 'SC_PERSONREGISTRATION_PROPERTIES')
         THEN 'OK' ELSE 'WRONG CASEID' END AS CaseStatus,
    ch.CHANGERECORDID,
    ch.TOPICOFCHANGE
FROM CHANGES ch
WHERE ch.CHANGESRECORDID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'CHANGES'
);

-- 5. Replayed MUTATION
PRINT '';
PRINT '=== 5. Replayed MUTATION ===';
SELECT 
    mu.MUTATIONRECORDID,
    mu.CASEID AS MutCaseID,
    (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @ReplayRunID AND TableName = 'SC_PERSONREGISTRATION_PROPERTIES') AS ExpectedCaseID,
    CASE WHEN mu.CASEID = (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @ReplayRunID AND TableName = 'SC_PERSONREGISTRATION_PROPERTIES')
         THEN 'OK' ELSE 'WRONG CASEID' END AS CaseStatus
FROM MUTATION mu
WHERE mu.MUTATIONRECORDID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'MUTATION'
);

-- 6. Replayed CMFRECORD
PRINT '';
PRINT '=== 6. Replayed CMFRECORD ===';
SELECT 
    cr.ID,
    cr.CASEID AS RecordCaseID,
    cr.RECORDTYPE,
    (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @ReplayRunID AND TableName = 'CMFCASE') AS ExpectedCMFCaseID,
    CASE WHEN cr.CASEID = (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @ReplayRunID AND TableName = 'CMFCASE')
         THEN 'OK' ELSE 'WRONG CASEID' END AS CaseStatus
FROM CMFRECORD cr
WHERE cr.ID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'CMFRECORD'
);

-- 7. Individual with all columns
PRINT '';
PRINT '=== 7. Replayed Individual vs Original ===';
SELECT 
    'Original' AS Source,
    i.INDIVIDUALRECORDID, i.CASEID, i.FIRSTNAMES, i.SURNAME, i.GENDER, i.DATEOFBIRTH, i.NATIONALITY, i.RESIDENT
FROM SC_PERSONREGISTRATION_INDIVIDUAL i
WHERE i.INDIVIDUALRECORDID IN (
    SELECT CAST(OldPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'SC_PERSONREGISTRATION_INDIVIDUAL'
)
UNION ALL
SELECT 
    'Replayed' AS Source,
    i.INDIVIDUALRECORDID, i.CASEID, i.FIRSTNAMES, i.SURNAME, i.GENDER, i.DATEOFBIRTH, i.NATIONALITY, i.RESIDENT
FROM SC_PERSONREGISTRATION_INDIVIDUAL i
WHERE i.INDIVIDUALRECORDID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'SC_PERSONREGISTRATION_INDIVIDUAL'
);

-- 8. Check if CHANGES count is 0 for replayed case
PRINT '';
PRINT '=== 8. CHANGES count for replayed case ===';
DECLARE @NewCaseID BIGINT;
SELECT @NewCaseID = CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
WHERE ReplayRunID = @ReplayRunID AND TableName = 'SC_PERSONREGISTRATION_PROPERTIES';

SELECT 
    @NewCaseID AS ReplayedCaseID,
    (SELECT COUNT(*) FROM CHANGES WHERE CASEID = @NewCaseID) AS ChangesCount,
    (SELECT COUNT(*) FROM MUTATION WHERE CASEID = @NewCaseID) AS MutationCount;
