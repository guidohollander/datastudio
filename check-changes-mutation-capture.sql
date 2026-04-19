-- Check if CHANGES and MUTATION were captured
SELECT 
    TableName,
    COUNT(*) AS CapturedRowCount
FROM dbo.MigrationScenarioRow
GROUP BY TableName
ORDER BY TableName;

-- Check the captured CHANGES data
PRINT '';
PRINT '=== Sample Captured CHANGES ===';
SELECT TOP 2
    JSON_VALUE(RowJson, '$.CHANGESRECORDID') AS CHANGESRECORDID,
    JSON_VALUE(RowJson, '$.CHANGERECORDID') AS CHANGERECORDID,
    JSON_VALUE(RowJson, '$.TOPICOFCHANGE') AS TOPICOFCHANGE,
    JSON_VALUE(RowJson, '$.UPDATETYPE') AS UPDATETYPE,
    JSON_VALUE(RowJson, '$.CASEID') AS CASEID
FROM dbo.MigrationScenarioRow
WHERE TableName = 'CHANGES';

-- Check the captured MUTATION data
PRINT '';
PRINT '=== Sample Captured MUTATION ===';
SELECT TOP 2
    JSON_VALUE(RowJson, '$.MUTATIONRECORDID') AS MUTATIONRECORDID,
    JSON_VALUE(RowJson, '$.CASEID') AS CASEID,
    JSON_VALUE(RowJson, '$.CHANGESTATUS') AS CHANGESTATUS
FROM dbo.MigrationScenarioRow
WHERE TableName = 'MUTATION';

-- Check what was created in the last replay
PRINT '';
PRINT '=== Records Created in Last Replay ===';
DECLARE @ReplayRunID UNIQUEIDENTIFIER;
SELECT TOP 1 @ReplayRunID = ReplayRunID
FROM dbo.MigrationScenarioReplayRun
ORDER BY ReplayRunID DESC;

SELECT 
    TableName,
    COUNT(*) AS RecordsCreated
FROM dbo.MigrationScenarioReplayMap
WHERE ReplayRunID = @ReplayRunID
GROUP BY TableName
ORDER BY TableName;
