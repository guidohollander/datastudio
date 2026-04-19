-- Verify if the latest replay was done AFTER the relationship fix

-- Get the latest replay run
DECLARE @ReplayRunID UNIQUEIDENTIFIER;
DECLARE @ReplayTime DATETIME2;
SELECT TOP 1 
    @ReplayRunID = ReplayRunID,
    @ReplayTime = CreatedAt
FROM dbo.MigrationScenarioReplayRun
ORDER BY CreatedAt DESC;

PRINT '=== Latest Replay Run ===';
PRINT 'ReplayRunID: ' + CAST(@ReplayRunID AS NVARCHAR(50));
PRINT 'Created At: ' + CAST(@ReplayTime AS NVARCHAR(50));

-- Check when the relationship was fixed
PRINT '';
PRINT '=== When was the relationship fixed? ===';
SELECT TOP 1
    RelationshipID,
    ParentTable,
    ParentColumn,
    ChildTable,
    ChildColumn,
    Source,
    Notes
FROM dbo.MigrationTableRelationships
WHERE ParentTable = 'SC_PERSONREGISTRATION_INDIVIDUAL'
  AND ChildTable = 'CHANGES'
  AND ChildColumn = 'CHANGERECORDID'
ORDER BY RelationshipID DESC;

-- Check if replay was done after the fix
PRINT '';
PRINT '=== Was the latest replay done AFTER the relationship fix? ===';
PRINT 'You need to perform a NEW replay for the fix to take effect!';
PRINT 'The relationship fix only affects FUTURE replays, not past ones.';

-- Check the latest replayed CHANGES
PRINT '';
PRINT '=== Latest Replayed CHANGES ===';
SELECT 
    ch.CHANGESRECORDID,
    ch.CASEID,
    ch.CHANGERECORDID,
    ch.TOPICOFCHANGE,
    CASE 
        WHEN i.INDIVIDUALRECORDID IS NOT NULL THEN 'Points to Individual ID=' + CAST(i.INDIVIDUALRECORDID AS NVARCHAR(20))
        WHEN r.ID IS NOT NULL THEN 'Points to CMFRECORD ID=' + CAST(r.ID AS NVARCHAR(20)) + ' (WRONG!)'
        ELSE 'Points to nothing (BROKEN!)'
    END AS PointsTo
FROM CHANGES ch
LEFT JOIN SC_PERSONREGISTRATION_INDIVIDUAL i ON i.INDIVIDUALRECORDID = ch.CHANGERECORDID
LEFT JOIN CMFRECORD r ON r.ID = ch.CHANGERECORDID
WHERE ch.CHANGESRECORDID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'CHANGES'
)
ORDER BY ch.CHANGESRECORDID;

-- Check if CHANGES exist in Be Informed application view
PRINT '';
PRINT '=== Do CHANGES appear in the case? ===';
SELECT 
    p.CASEID,
    COUNT(ch.CHANGESRECORDID) AS ChangeCount
FROM SC_PERSONREGISTRATION_PROPERTIES p
LEFT JOIN CHANGES ch ON ch.CASEID = p.CASEID
WHERE p.CASEID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'SC_PERSONREGISTRATION_PROPERTIES'
)
GROUP BY p.CASEID;

-- Check what tables were replayed
PRINT '';
PRINT '=== What tables were replayed? ===';
SELECT 
    TableName,
    COUNT(*) AS RecordCount
FROM dbo.MigrationScenarioReplayMap
WHERE ReplayRunID = @ReplayRunID
GROUP BY TableName
ORDER BY TableName;
