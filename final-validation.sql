-- Final end-to-end validation: run a fresh replay and verify all data

DECLARE @RunID UNIQUEIDENTIFIER;
SELECT TOP 1 @RunID = RunID
FROM dbo.MigrationScenarioRun
WHERE EndedAt IS NOT NULL
ORDER BY StartedAt DESC;

-- Run replay
DECLARE @Results TABLE (ReplayRunID UNIQUEIDENTIFIER, Iteration INT);
INSERT INTO @Results
EXEC dbo.ReplayScenarioRun @SourceRunID = @RunID, @Times = 1, @Commit = 1;

DECLARE @RR UNIQUEIDENTIFIER;
SELECT @RR = ReplayRunID FROM @Results;

-- Get key IDs
DECLARE @NewCMFCase BIGINT, @NewPropsCase BIGINT, @OldCMFCase BIGINT, @OldPropsCase BIGINT;
SELECT @OldCMFCase = CAST(OldPkValue AS BIGINT), @NewCMFCase = CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @RR AND TableName = 'CMFCASE';
SELECT @OldPropsCase = CAST(OldPkValue AS BIGINT), @NewPropsCase = CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @RR AND TableName = 'SC_PERSONREGISTRATION_PROPERTIES';

PRINT '========================================';
PRINT '  REPLAY VALIDATION REPORT';
PRINT '========================================';
PRINT 'ReplayRunID: ' + CAST(@RR AS VARCHAR(50));
PRINT 'Old CMFCASE ID: ' + CAST(@OldCMFCase AS VARCHAR) + ' -> New: ' + CAST(@NewCMFCase AS VARCHAR);
PRINT 'Old Props CASEID: ' + CAST(@OldPropsCase AS VARCHAR) + ' -> New: ' + CAST(@NewPropsCase AS VARCHAR);

-- 1. Table counts
PRINT '';
PRINT '--- Replayed Table Counts ---';
SELECT m.TableName, COUNT(*) AS [RowCount]
FROM dbo.MigrationScenarioReplayMap m
WHERE m.ReplayRunID = @RR
GROUP BY m.TableName
ORDER BY m.TableName;

-- 2. CHANGES verification
PRINT '';
PRINT '--- CHANGES Verification ---';
SELECT 
    ch.CHANGESRECORDID,
    ch.CASEID,
    CASE WHEN ch.CASEID = @NewPropsCase THEN 'PASS' ELSE 'FAIL (expected ' + CAST(@NewPropsCase AS VARCHAR) + ')' END AS CASEID_Check,
    ch.CHANGERECORDID,
    CASE WHEN EXISTS (SELECT 1 FROM dbo.MigrationScenarioReplayMap m WHERE m.ReplayRunID = @RR AND m.NewPkValue = ch.CHANGERECORDID) THEN 'PASS (remapped)' ELSE 'Original' END AS CHANGERECORDID_Check,
    ch.TOPICOFCHANGE
FROM CHANGES ch
WHERE ch.CHANGESRECORDID IN (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @RR AND TableName = 'CHANGES');

-- 3. MUTATION verification
PRINT '';
PRINT '--- MUTATION Verification ---';
SELECT 
    mu.MUTATIONRECORDID,
    mu.CASEID,
    CASE WHEN mu.CASEID = @NewPropsCase THEN 'PASS' ELSE 'FAIL' END AS CASEID_Check
FROM MUTATION mu
WHERE mu.MUTATIONRECORDID IN (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @RR AND TableName = 'MUTATION');

-- 4. CMFRECORD verification
PRINT '';
PRINT '--- CMFRECORD Verification ---';
SELECT 
    cr.ID,
    cr.CASEID,
    CASE WHEN cr.CASEID = @NewCMFCase THEN 'PASS' ELSE 'FAIL' END AS CASEID_Check,
    cr.RECORDTYPE
FROM CMFRECORD cr
WHERE cr.ID IN (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @RR AND TableName = 'CMFRECORD');

-- 5. Individual verification
PRINT '';
PRINT '--- Individual Verification ---';
SELECT 
    i.INDIVIDUALRECORDID,
    i.CASEID,
    CASE WHEN i.CASEID = @NewPropsCase THEN 'PASS' ELSE 'FAIL' END AS CASEID_Check,
    i.FIRSTNAMES,
    i.SURNAME
FROM SC_PERSONREGISTRATION_INDIVIDUAL i
WHERE i.INDIVIDUALRECORDID IN (SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap WHERE ReplayRunID = @RR AND TableName = 'SC_PERSONREGISTRATION_INDIVIDUAL');

-- 6. All other tables CASEID check
PRINT '';
PRINT '--- All Tables CASEID Summary ---';
SELECT 
    m.TableName,
    CAST(m.NewPkValue AS BIGINT) AS NewID,
    CASE 
        WHEN m.TableName IN ('CMFCASE') THEN 'N/A (is the case)'
        WHEN m.TableName IN ('CMFRECORD', 'CMFEVENT', 'CMFTRANSITION') THEN
            CASE WHEN EXISTS (
                SELECT 1 FROM CMFRECORD cr WHERE cr.ID = CAST(m.NewPkValue AS BIGINT) AND cr.CASEID = @NewCMFCase
            ) OR EXISTS (
                SELECT 1 FROM CMFEVENT ev WHERE ev.ID = CAST(m.NewPkValue AS BIGINT) AND ev.CASEID = @NewCMFCase
            ) OR EXISTS (
                SELECT 1 FROM CMFTRANSITION tr WHERE tr.ID = CAST(m.NewPkValue AS BIGINT) AND tr.CASEID = @NewCMFCase
            ) THEN 'PASS' ELSE 'FAIL' END
        ELSE 'See above'
    END AS CASEID_Status
FROM dbo.MigrationScenarioReplayMap m
WHERE m.ReplayRunID = @RR
ORDER BY m.TableName;

-- 7. Final count summary
PRINT '';
PRINT '--- Final Summary ---';
SELECT 
    @NewPropsCase AS NewCaseID,
    (SELECT COUNT(*) FROM CHANGES WHERE CASEID = @NewPropsCase) AS ChangesCount,
    (SELECT COUNT(*) FROM MUTATION WHERE CASEID = @NewPropsCase) AS MutationCount,
    (SELECT COUNT(*) FROM SC_PERSONREGISTRATION_INDIVIDUAL WHERE CASEID = @NewPropsCase) AS IndividualCount,
    (SELECT COUNT(*) FROM CMFRECORD WHERE CASEID = @NewCMFCase) AS CMFRecordCount;
