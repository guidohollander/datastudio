-- Check if CMFRECORD is in the domain contract

PRINT '=== CMFRECORD in Contract ===';
SELECT 
    c.ComponentKey,
    c.PhysicalTable,
    c.MinOccurs,
    c.MaxOccurs,
    COUNT(f.FieldKey) AS FieldCount
FROM dbo.MigrationDomainComponent c
LEFT JOIN dbo.MigrationDomainField f ON f.ObjectKey = c.ObjectKey AND f.ComponentKey = c.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.PhysicalTable = 'CMFRECORD'
GROUP BY c.ComponentKey, c.PhysicalTable, c.MinOccurs, c.MaxOccurs;

-- Check CMFRECORD fields
PRINT '';
PRINT '=== CMFRECORD Fields in Contract ===';
SELECT 
    f.FieldKey,
    f.PhysicalColumn,
    f.DataType,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.PhysicalTable = 'CMFRECORD'
ORDER BY f.FieldKey;

-- Check if replayed data has CMFRECORD
PRINT '';
PRINT '=== Replayed CMFRECORD Records ===';
DECLARE @ReplayRunID UNIQUEIDENTIFIER;
SELECT TOP 1 @ReplayRunID = ReplayRunID
FROM dbo.MigrationScenarioReplayRun
ORDER BY ReplayRunID DESC;

IF @ReplayRunID IS NOT NULL
BEGIN
    SELECT 
        r.ID,
        r.CASEID,
        r.RECORDTYPE,
        'Replayed' AS Source
    FROM CMFRECORD r
    WHERE r.ID IN (
        SELECT NewPkValue FROM dbo.MigrationScenarioReplayMap
        WHERE ReplayRunID = @ReplayRunID AND TableName = 'CMFRECORD'
    );
    
    -- Check if CHANGES.CHANGERECORDID points to replayed CMFRECORD
    PRINT '';
    PRINT '=== Do replayed CHANGES point to replayed CMFRECORD? ===';
    SELECT 
        ch.CHANGESRECORDID,
        ch.CHANGERECORDID,
        ch.TOPICOFCHANGE,
        CASE 
            WHEN r.ID IS NOT NULL THEN 'Points to replayed CMFRECORD'
            ELSE 'BROKEN - does not point to replayed CMFRECORD'
        END AS Status
    FROM CHANGES ch
    LEFT JOIN CMFRECORD r ON r.ID = ch.CHANGERECORDID
    WHERE ch.CHANGESRECORDID IN (
        SELECT NewPkValue FROM dbo.MigrationScenarioReplayMap
        WHERE ReplayRunID = @ReplayRunID AND TableName = 'CHANGES'
    );
END
ELSE
BEGIN
    PRINT 'No replay data found';
END
