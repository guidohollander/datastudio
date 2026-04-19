-- Check and add CMFRECORD relationships to MigrationTableRelationships

PRINT '=== Current Relationships for CHANGES and CMFRECORD ===';
SELECT 
    RelationshipID,
    ParentTable,
    ParentColumn,
    ChildTable,
    ChildColumn,
    IsActive,
    Source
FROM dbo.MigrationTableRelationships
WHERE (ParentTable IN ('CMFRECORD', 'CHANGES', 'MUTATION') OR ChildTable IN ('CMFRECORD', 'CHANGES', 'MUTATION'))
  AND IsActive = 1
ORDER BY ParentTable, ChildTable;

-- Add CMFRECORD -> CHANGES (CHANGERECORDID) relationship
PRINT '';
PRINT '=== Adding CMFRECORD -> CHANGES.CHANGERECORDID relationship ===';
IF NOT EXISTS (
    SELECT 1 FROM dbo.MigrationTableRelationships
    WHERE ParentTable = 'CMFRECORD'
      AND ParentColumn = 'ID'
      AND ChildTable = 'CHANGES'
      AND ChildColumn = 'CHANGERECORDID'
      AND IsActive = 1
)
BEGIN
    INSERT INTO dbo.MigrationTableRelationships (ParentTable, ParentColumn, ChildTable, ChildColumn, IsActive, Source, Notes)
    VALUES ('CMFRECORD', 'ID', 'CHANGES', 'CHANGERECORDID', 1, 'Analysis', 'CHANGES.CHANGERECORDID references CMFRECORD.ID - the record being changed');
    PRINT 'Added CMFRECORD.ID -> CHANGES.CHANGERECORDID relationship';
END
ELSE
BEGIN
    PRINT 'Relationship already exists';
END

-- Add CMFRECORD -> CHANGES (MUTATIONRECORDID) relationship
PRINT '';
PRINT '=== Adding CMFRECORD -> CHANGES.MUTATIONRECORDID relationship ===';
IF NOT EXISTS (
    SELECT 1 FROM dbo.MigrationTableRelationships
    WHERE ParentTable = 'CMFRECORD'
      AND ParentColumn = 'ID'
      AND ChildTable = 'CHANGES'
      AND ChildColumn = 'MUTATIONRECORDID'
      AND IsActive = 1
)
BEGIN
    INSERT INTO dbo.MigrationTableRelationships (ParentTable, ParentColumn, ChildTable, ChildColumn, IsActive, Source, Notes)
    VALUES ('CMFRECORD', 'ID', 'CHANGES', 'MUTATIONRECORDID', 1, 'Analysis', 'CHANGES.MUTATIONRECORDID references CMFRECORD.ID - the mutation record');
    PRINT 'Added CMFRECORD.ID -> CHANGES.MUTATIONRECORDID relationship';
END
ELSE
BEGIN
    PRINT 'Relationship already exists';
END

-- Add CMFCASE -> CMFRECORD relationship
PRINT '';
PRINT '=== Adding CMFCASE -> CMFRECORD relationship ===';
IF NOT EXISTS (
    SELECT 1 FROM dbo.MigrationTableRelationships
    WHERE ParentTable = 'CMFCASE'
      AND ParentColumn = 'ID'
      AND ChildTable = 'CMFRECORD'
      AND ChildColumn = 'CASEID'
      AND IsActive = 1
)
BEGIN
    INSERT INTO dbo.MigrationTableRelationships (ParentTable, ParentColumn, ChildTable, ChildColumn, IsActive, Source, Notes)
    VALUES ('CMFCASE', 'ID', 'CMFRECORD', 'CASEID', 1, 'Analysis', 'CMFRECORD.CASEID references CMFCASE.ID');
    PRINT 'Added CMFCASE.ID -> CMFRECORD.CASEID relationship';
END
ELSE
BEGIN
    PRINT 'Relationship already exists';
END

-- Verify the relationships
PRINT '';
PRINT '=== Updated Relationships ===';
SELECT 
    RelationshipID,
    ParentTable,
    ParentColumn,
    ChildTable,
    ChildColumn,
    IsActive,
    Source,
    Notes
FROM dbo.MigrationTableRelationships
WHERE (ParentTable IN ('CMFRECORD', 'CHANGES', 'MUTATION', 'CMFCASE') OR ChildTable IN ('CMFRECORD', 'CHANGES', 'MUTATION'))
  AND IsActive = 1
ORDER BY ParentTable, ChildTable;
