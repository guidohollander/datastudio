-- Check the most recent replay issues
DECLARE @ReplayRunID UNIQUEIDENTIFIER;
SELECT TOP 1 @ReplayRunID = ReplayRunID
FROM dbo.MigrationScenarioReplayRun
ORDER BY ReplayRunID DESC;

-- Get replayed individual CaseIDs
DECLARE @ReplayedCases TABLE (CASEID BIGINT);
INSERT INTO @ReplayedCases
SELECT DISTINCT i.CASEID
FROM SC_PERSONREGISTRATION_INDIVIDUAL i
WHERE i.INDIVIDUALRECORDID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID
      AND TableName = 'SC_PERSONREGISTRATION_INDIVIDUAL'
);

-- Check home addresses for these cases
SELECT 
    'Replayed' AS Source,
    h.HOMEADDRESSRECORDID,
    h.CASEID,
    h.HOMEADDRESSCOUNTRY,
    h.HOMEADDRESSREGION,
    h.HOMEADDRESSSTREET
FROM SC_PERSONREGISTRATION_HOMEADDRESS h
WHERE h.CASEID IN (SELECT CASEID FROM @ReplayedCases)
ORDER BY h.CASEID, h.HOMEADDRESSRECORDID;

-- Check CHANGES for these cases
PRINT '';
PRINT '=== CHANGES for replayed cases ===';
SELECT 
    c.CHANGESRECORDID,
    c.CHANGERECORDID,
    c.CASEID,
    c.TOPICOFCHANGE,
    c.UPDATETYPE
FROM CHANGES c
WHERE c.CASEID IN (SELECT CASEID FROM @ReplayedCases)
ORDER BY c.CASEID, c.CHANGESRECORDID;

-- Check MUTATION for these cases
PRINT '';
PRINT '=== MUTATION for replayed cases ===';
SELECT 
    m.MUTATIONRECORDID,
    m.CASEID,
    m.CHANGESTATUS
FROM MUTATION m
WHERE m.CASEID IN (SELECT CASEID FROM @ReplayedCases)
ORDER BY m.CASEID, m.MUTATIONRECORDID;

-- Check what the contract has for homeaddress fields
PRINT '';
PRINT '=== Home Address Contract Fields ===';
SELECT 
    f.FieldKey,
    f.PhysicalColumn,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ComponentKey = 'homeaddress'
ORDER BY f.FieldKey;
