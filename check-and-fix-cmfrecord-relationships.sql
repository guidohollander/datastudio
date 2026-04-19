-- Check and fix CMFRECORD relationships in MigrationScenarioRelationship table

DECLARE @RunID UNIQUEIDENTIFIER;
SELECT TOP 1 @RunID = RunID
FROM dbo.MigrationScenarioRun
WHERE EndedAt IS NOT NULL
ORDER BY StartedAt DESC;

PRINT '=== Current Relationships for CHANGES ===';
SELECT 
    ParentTable,
    ParentColumn,
    ChildTable,
    ChildColumn,
    RelationshipType
FROM dbo.MigrationScenarioRelationship
WHERE RunID = @RunID
  AND (ParentTable = 'CHANGES' OR ChildTable = 'CHANGES')
ORDER BY ParentTable, ChildTable;

PRINT '';
PRINT '=== Current Relationships for CMFRECORD ===';
SELECT 
    ParentTable,
    ParentColumn,
    ChildTable,
    ChildColumn,
    RelationshipType
FROM dbo.MigrationScenarioRelationship
WHERE RunID = @RunID
  AND (ParentTable = 'CMFRECORD' OR ChildTable = 'CMFRECORD')
ORDER BY ParentTable, ChildTable;

-- Add missing relationship: CMFRECORD -> CHANGES (CHANGES.CHANGERECORDID references CMFRECORD.ID)
PRINT '';
PRINT '=== Adding CMFRECORD -> CHANGES relationship ===';

IF NOT EXISTS (
    SELECT 1 FROM dbo.MigrationScenarioRelationship
    WHERE RunID = @RunID
      AND ParentTable = 'CMFRECORD'
      AND ParentColumn = 'ID'
      AND ChildTable = 'CHANGES'
      AND ChildColumn = 'CHANGERECORDID'
)
BEGIN
    INSERT INTO dbo.MigrationScenarioRelationship (RunID, ParentTable, ParentColumn, ChildTable, ChildColumn, RelationshipType)
    VALUES (@RunID, 'CMFRECORD', 'ID', 'CHANGES', 'CHANGERECORDID', 'FK');
    PRINT 'Added CMFRECORD.ID -> CHANGES.CHANGERECORDID relationship';
END
ELSE
BEGIN
    PRINT 'Relationship already exists';
END

-- Add missing relationship: CMFRECORD -> CHANGES (CHANGES.MUTATIONRECORDID references CMFRECORD.ID for mutation records)
IF NOT EXISTS (
    SELECT 1 FROM dbo.MigrationScenarioRelationship
    WHERE RunID = @RunID
      AND ParentTable = 'CMFRECORD'
      AND ParentColumn = 'ID'
      AND ChildTable = 'CHANGES'
      AND ChildColumn = 'MUTATIONRECORDID'
)
BEGIN
    INSERT INTO dbo.MigrationScenarioRelationship (RunID, ParentTable, ParentColumn, ChildTable, ChildColumn, RelationshipType)
    VALUES (@RunID, 'CMFRECORD', 'ID', 'CHANGES', 'MUTATIONRECORDID', 'FK');
    PRINT 'Added CMFRECORD.ID -> CHANGES.MUTATIONRECORDID relationship';
END
ELSE
BEGIN
    PRINT 'Relationship already exists';
END

-- Verify the relationships are now correct
PRINT '';
PRINT '=== Updated Relationships ===';
SELECT 
    ParentTable,
    ParentColumn,
    ChildTable,
    ChildColumn,
    RelationshipType
FROM dbo.MigrationScenarioRelationship
WHERE RunID = @RunID
  AND (ParentTable = 'CMFRECORD' OR ChildTable = 'CMFRECORD' OR ParentTable = 'CHANGES' OR ChildTable = 'CHANGES')
ORDER BY ParentTable, ChildTable;
