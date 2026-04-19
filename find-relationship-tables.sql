-- Find all tables related to relationships
SELECT 
    TABLE_NAME,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME LIKE '%Relationship%'
ORDER BY TABLE_NAME;

-- Check MigrationRelationship table
PRINT '';
PRINT '=== MigrationRelationship Schema ===';
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'MigrationRelationship'
ORDER BY ORDINAL_POSITION;

-- Check current relationships
PRINT '';
PRINT '=== Current Relationships ===';
SELECT 
    RelationshipID,
    FromTable,
    FromColumn,
    ToTable,
    ToColumn,
    RelationshipType
FROM dbo.MigrationRelationship
WHERE FromTable IN ('CMFRECORD', 'CHANGES', 'MUTATION')
   OR ToTable IN ('CMFRECORD', 'CHANGES', 'MUTATION')
ORDER BY FromTable, ToTable;
