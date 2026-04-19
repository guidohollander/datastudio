-- Analyze why replayed cases don't show CHANGES records

-- Get the latest replay run
DECLARE @ReplayRunID UNIQUEIDENTIFIER;
SELECT TOP 1 @ReplayRunID = ReplayRunID
FROM dbo.MigrationScenarioReplayRun
ORDER BY ReplayRunID DESC;

PRINT '=== Latest Replay Run ===';
PRINT 'ReplayRunID: ' + CAST(@ReplayRunID AS NVARCHAR(50));

-- Get replayed case
PRINT '';
PRINT '=== Replayed Case ===';
SELECT 
    p.CASEID,
    p.CASESTATUS,
    i.INDIVIDUALRECORDID,
    i.FIRSTNAMES,
    i.SURNAME
FROM SC_PERSONREGISTRATION_PROPERTIES p
INNER JOIN SC_PERSONREGISTRATION_INDIVIDUAL i ON i.CASEID = p.CASEID
WHERE p.CASEID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'SC_PERSONREGISTRATION_PROPERTIES'
);

-- Get replayed CMFRECORD
PRINT '';
PRINT '=== Replayed CMFRECORD ===';
SELECT 
    r.ID,
    r.CASEID,
    r.RECORDTYPE
FROM CMFRECORD r
WHERE r.ID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'CMFRECORD'
)
ORDER BY r.RECORDTYPE, r.ID;

-- Get replayed CHANGES
PRINT '';
PRINT '=== Replayed CHANGES ===';
SELECT 
    ch.CHANGESRECORDID,
    ch.CASEID,
    ch.CHANGERECORDID,
    ch.MUTATIONRECORDID,
    ch.TOPICOFCHANGE
FROM CHANGES ch
WHERE ch.CHANGESRECORDID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'CHANGES'
)
ORDER BY ch.CHANGESRECORDID;

-- Check if CHANGES.CHANGERECORDID points to valid CMFRECORD
PRINT '';
PRINT '=== Do replayed CHANGES point to valid CMFRECORD? ===';
SELECT 
    ch.CHANGESRECORDID,
    ch.CHANGERECORDID,
    ch.TOPICOFCHANGE,
    CASE 
        WHEN r.ID IS NOT NULL THEN 'Valid - points to CMFRECORD ID=' + CAST(r.ID AS NVARCHAR(20))
        ELSE 'BROKEN - CMFRECORD not found'
    END AS Status,
    r.RECORDTYPE
FROM CHANGES ch
LEFT JOIN CMFRECORD r ON r.ID = ch.CHANGERECORDID
WHERE ch.CHANGESRECORDID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'CHANGES'
);

-- Check if CHANGES.CASEID points to valid case
PRINT '';
PRINT '=== Do replayed CHANGES point to valid case? ===';
SELECT 
    ch.CHANGESRECORDID,
    ch.CASEID,
    CASE 
        WHEN p.CASEID IS NOT NULL THEN 'Valid - points to case ID=' + CAST(p.CASEID AS NVARCHAR(20))
        ELSE 'BROKEN - case not found'
    END AS Status
FROM CHANGES ch
LEFT JOIN SC_PERSONREGISTRATION_PROPERTIES p ON p.CASEID = ch.CASEID
WHERE ch.CHANGESRECORDID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'CHANGES'
);

-- Compare with original data
PRINT '';
PRINT '=== Original CHANGES for comparison ===';
DECLARE @OriginalRunID UNIQUEIDENTIFIER;
SELECT TOP 1 @OriginalRunID = RunID
FROM dbo.MigrationScenarioRun
WHERE EndedAt IS NOT NULL
ORDER BY StartedAt DESC;

SELECT 
    ch.CHANGESRECORDID,
    ch.CASEID,
    ch.CHANGERECORDID,
    ch.MUTATIONRECORDID,
    ch.TOPICOFCHANGE,
    r.RECORDTYPE AS ChangeRecordType
FROM CHANGES ch
LEFT JOIN CMFRECORD r ON r.ID = ch.CHANGERECORDID
WHERE ch.CHANGESRECORDID IN (
    SELECT CAST(PkValue AS BIGINT) FROM dbo.MigrationScenarioRow
    WHERE RunID = @OriginalRunID AND TableName = 'CHANGES'
);

-- Check replay map for CHANGES
PRINT '';
PRINT '=== Replay Map for CHANGES ===';
SELECT 
    TableName,
    CAST(OldPkValue AS BIGINT) AS OldID,
    CAST(NewPkValue AS BIGINT) AS NewID
FROM dbo.MigrationScenarioReplayMap
WHERE ReplayRunID = @ReplayRunID
  AND TableName IN ('CHANGES', 'CMFRECORD', 'SC_PERSONREGISTRATION_PROPERTIES', 'SC_PERSONREGISTRATION_INDIVIDUAL')
ORDER BY TableName, OldPkValue;

-- Check if CMFCASE was replayed
PRINT '';
PRINT '=== Was CMFCASE replayed? ===';
SELECT 
    c.ID,
    'Replayed' AS Source
FROM CMFCASE c
WHERE c.ID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'CMFCASE'
);
