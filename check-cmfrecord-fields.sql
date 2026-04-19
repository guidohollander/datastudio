-- Check CMFRECORD fields in contract and their relationships
SELECT 
    f.FieldKey,
    f.PhysicalColumn,
    f.DataType,
    f.Notes AS Generator,
    c.PhysicalTable
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.PhysicalTable = 'CMFRECORD'
ORDER BY f.FieldKey;

-- Check relationships WHERE CMFRECORD is the child
PRINT '';
PRINT '=== Relationships where CMFRECORD is child ===';
SELECT 
    ParentTable,
    ParentColumn,
    ChildTable,
    ChildColumn
FROM dbo.MigrationTableRelationships
WHERE ChildTable = 'CMFRECORD'
  AND IsActive = 1;

-- Check relationships WHERE CMFRECORD is the parent
PRINT '';
PRINT '=== Relationships where CMFRECORD is parent ===';
SELECT 
    ParentTable,
    ParentColumn,
    ChildTable,
    ChildColumn
FROM dbo.MigrationTableRelationships
WHERE ParentTable = 'CMFRECORD'
  AND IsActive = 1;
