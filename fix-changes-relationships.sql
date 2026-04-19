-- Fix CHANGES relationships - CHANGERECORDID points to SC_PERSONREGISTRATION_INDIVIDUAL, not CMFRECORD

PRINT '=== Removing incorrect CMFRECORD -> CHANGES.CHANGERECORDID relationship ===';
DELETE FROM dbo.MigrationTableRelationships
WHERE ParentTable = 'CMFRECORD'
  AND ParentColumn = 'ID'
  AND ChildTable = 'CHANGES'
  AND ChildColumn = 'CHANGERECORDID';

PRINT 'Removed incorrect relationship';

PRINT '';
PRINT '=== Adding correct SC_PERSONREGISTRATION_INDIVIDUAL -> CHANGES.CHANGERECORDID relationship ===';
IF NOT EXISTS (
    SELECT 1 FROM dbo.MigrationTableRelationships
    WHERE ParentTable = 'SC_PERSONREGISTRATION_INDIVIDUAL'
      AND ParentColumn = 'INDIVIDUALRECORDID'
      AND ChildTable = 'CHANGES'
      AND ChildColumn = 'CHANGERECORDID'
      AND IsActive = 1
)
BEGIN
    INSERT INTO dbo.MigrationTableRelationships (ParentTable, ParentColumn, ChildTable, ChildColumn, IsActive, Source, Notes)
    VALUES ('SC_PERSONREGISTRATION_INDIVIDUAL', 'INDIVIDUALRECORDID', 'CHANGES', 'CHANGERECORDID', 1, 'Analysis', 'CHANGES.CHANGERECORDID references SC_PERSONREGISTRATION_INDIVIDUAL.INDIVIDUALRECORDID - the individual being changed');
    PRINT 'Added correct relationship';
END
ELSE
BEGIN
    PRINT 'Relationship already exists';
END

-- Keep the CMFRECORD -> CHANGES.MUTATIONRECORDID relationship (this one is correct)
PRINT '';
PRINT '=== Verifying CMFRECORD -> CHANGES.MUTATIONRECORDID relationship ===';
IF EXISTS (
    SELECT 1 FROM dbo.MigrationTableRelationships
    WHERE ParentTable = 'CMFRECORD'
      AND ParentColumn = 'ID'
      AND ChildTable = 'CHANGES'
      AND ChildColumn = 'MUTATIONRECORDID'
      AND IsActive = 1
)
BEGIN
    PRINT 'MUTATIONRECORDID relationship exists (correct)';
END

-- Verify the corrected relationships
PRINT '';
PRINT '=== Updated Relationships for CHANGES ===';
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
WHERE ChildTable = 'CHANGES'
  AND IsActive = 1
ORDER BY ParentTable, ChildColumn;
