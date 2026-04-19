-- Verify the latest replay has correct CASEID remapping

DECLARE @RR UNIQUEIDENTIFIER = '38A70483-F6C5-451F-911F-0FF049A26F75';

PRINT '=== 1. Replay Map ===';
SELECT TableName, CAST(OldPkValue AS BIGINT) AS OldID, CAST(NewPkValue AS BIGINT) AS NewID
FROM dbo.MigrationScenarioReplayMap
WHERE ReplayRunID = @RR
ORDER BY TableName, OldPkValue;

-- Get expected new case IDs
DECLARE @NewPropsCaseID BIGINT, @NewCMFCaseID BIGINT;
SELECT @NewPropsCaseID = CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @RR AND TableName = 'SC_PERSONREGISTRATION_PROPERTIES';
SELECT @NewCMFCaseID = CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @RR AND TableName = 'CMFCASE';

PRINT '';
PRINT '=== 2. New Case IDs ===';
PRINT 'SC_PERSONREGISTRATION_PROPERTIES CASEID: ' + CAST(@NewPropsCaseID AS VARCHAR);
PRINT 'CMFCASE ID: ' + CAST(@NewCMFCaseID AS VARCHAR);

PRINT '';
PRINT '=== 3. CHANGES for replayed case ===';
SELECT ch.CHANGESRECORDID, ch.CASEID, ch.CHANGERECORDID, ch.TOPICOFCHANGE,
    CASE WHEN ch.CASEID = @NewPropsCaseID THEN 'OK' ELSE 'WRONG' END AS CaseStatus
FROM CHANGES ch
WHERE ch.CHANGESRECORDID IN (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @RR AND TableName = 'CHANGES');

PRINT '';
PRINT '=== 4. MUTATION for replayed case ===';
SELECT mu.MUTATIONRECORDID, mu.CASEID,
    CASE WHEN mu.CASEID = @NewPropsCaseID THEN 'OK' ELSE 'WRONG' END AS CaseStatus
FROM MUTATION mu
WHERE mu.MUTATIONRECORDID IN (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @RR AND TableName = 'MUTATION');

PRINT '';
PRINT '=== 5. CMFRECORD for replayed case ===';
SELECT cr.ID, cr.CASEID, cr.RECORDTYPE,
    CASE WHEN cr.CASEID = @NewCMFCaseID THEN 'OK' ELSE 'WRONG' END AS CaseStatus
FROM CMFRECORD cr
WHERE cr.ID IN (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @RR AND TableName = 'CMFRECORD');

PRINT '';
PRINT '=== 6. CHANGES count for replayed case ===';
SELECT @NewPropsCaseID AS ReplayedCaseID,
    (SELECT COUNT(*) FROM CHANGES WHERE CASEID = @NewPropsCaseID) AS ChangesCount,
    (SELECT COUNT(*) FROM MUTATION WHERE CASEID = @NewPropsCaseID) AS MutationCount;

PRINT '';
PRINT '=== 7. Individual ===';
SELECT i.INDIVIDUALRECORDID, i.CASEID, i.FIRSTNAMES, i.SURNAME,
    CASE WHEN i.CASEID = @NewPropsCaseID THEN 'OK' ELSE 'WRONG' END AS CaseStatus
FROM SC_PERSONREGISTRATION_INDIVIDUAL i
WHERE i.INDIVIDUALRECORDID IN (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @RR AND TableName = 'SC_PERSONREGISTRATION_INDIVIDUAL');
