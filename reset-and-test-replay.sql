-- Reset replayed data so user can test with fixed contract
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;

-- Get all replay runs
DECLARE @ReplayRuns TABLE (ReplayRunID UNIQUEIDENTIFIER);
INSERT INTO @ReplayRuns
SELECT DISTINCT ReplayRunID
FROM dbo.MigrationScenarioReplayRun;

PRINT 'Deleting replayed data...';

-- Delete replayed individuals
DELETE i
FROM SC_PERSONREGISTRATION_INDIVIDUAL i
WHERE i.INDIVIDUALRECORDID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap m
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = m.ReplayRunID
    WHERE m.TableName = 'SC_PERSONREGISTRATION_INDIVIDUAL'
);

-- Delete replayed PROPERTIES
DELETE p
FROM SC_PERSONREGISTRATION_PROPERTIES p
WHERE p.CASEID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap m
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = m.ReplayRunID
    WHERE m.TableName = 'SC_PERSONREGISTRATION_PROPERTIES'
);

-- Delete replayed CHANGES
DELETE c
FROM CHANGES c
WHERE c.CHANGESRECORDID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap m
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = m.ReplayRunID
    WHERE m.TableName = 'CHANGES'
);

-- Delete replayed MUTATION
DELETE m
FROM MUTATION m
WHERE m.MUTATIONRECORDID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap map
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = map.ReplayRunID
    WHERE map.TableName = 'MUTATION'
);

-- Delete replayed CONTACTINFORMATION
DELETE c
FROM SC_PERSONREGISTRATION_CONTACTINFORMATION c
WHERE c.CONTACTRECORDID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap m
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = m.ReplayRunID
    WHERE m.TableName = 'SC_PERSONREGISTRATION_CONTACTINFORMATION'
);

-- Delete replayed HOMEADDRESS
DELETE h
FROM SC_PERSONREGISTRATION_HOMEADDRESS h
WHERE h.HOMEADDRESSRECORDID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap m
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = m.ReplayRunID
    WHERE m.TableName = 'SC_PERSONREGISTRATION_HOMEADDRESS'
);

-- Delete replayed PERSONIDENTIFICATION
DELETE p
FROM SC_PERSONREGISTRATION_PERSONIDENTIFICATION p
WHERE p.PERSONIDENTIFICATIONRECORDID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap m
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = m.ReplayRunID
    WHERE m.TableName = 'SC_PERSONREGISTRATION_PERSONIDENTIFICATION'
);

-- Delete replayed CMF records
DELETE FROM CMFTRANSITION
WHERE ID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap m
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = m.ReplayRunID
    WHERE m.TableName = 'CMFTRANSITION'
);

DELETE FROM CMFEVENT
WHERE ID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap m
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = m.ReplayRunID
    WHERE m.TableName = 'CMFEVENT'
);

DELETE FROM CMFRECORD
WHERE ID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap m
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = m.ReplayRunID
    WHERE m.TableName = 'CMFRECORD'
);

DELETE FROM CMFCASE
WHERE ID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap m
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = m.ReplayRunID
    WHERE m.TableName = 'CMFCASE'
);

DELETE FROM SC_USERASSIGNMENT
WHERE USERASSIGNMENTRECORDID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap m
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = m.ReplayRunID
    WHERE m.TableName = 'SC_USERASSIGNMENT'
);

DELETE FROM SC_WORKITEM
WHERE WORKITEMRECORDID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap m
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = m.ReplayRunID
    WHERE m.TableName = 'SC_WORKITEM'
);

DELETE FROM CMFUSER
WHERE ID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap m
    INNER JOIN @ReplayRuns r ON r.ReplayRunID = m.ReplayRunID
    WHERE m.TableName = 'CMFUSER'
);

-- Clear replay tracking
DELETE FROM dbo.MigrationScenarioReplayMap
WHERE ReplayRunID IN (SELECT ReplayRunID FROM @ReplayRuns);

DELETE FROM dbo.MigrationScenarioReplayRun
WHERE ReplayRunID IN (SELECT ReplayRunID FROM @ReplayRuns);

PRINT 'Cleanup complete. Ready to test replay with fixed contract.';
PRINT '';
PRINT '=== What was fixed ===';
PRINT '1. CASEID removed from CHANGES/MUTATION contracts - will be remapped automatically';
PRINT '2. HOMEADDRESSSTATUS set to literal(Active) instead of ctx()';
PRINT '3. CONTACTSTATUS and PERSONIDENTIFICATIONSTATUS also set to literal(Active)';
PRINT '';
PRINT 'Now replay again in the UI and CHANGES/MUTATION should be linked correctly.';
