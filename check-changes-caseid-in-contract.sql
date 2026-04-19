-- Check if CHANGES.CASEID is in the domain contract

PRINT '=== Is CHANGES.CASEID in the contract? ===';
SELECT 
    c.ComponentKey,
    c.PhysicalTable,
    f.FieldKey,
    f.PhysicalColumn,
    f.DataType,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.PhysicalTable = 'CHANGES'
  AND f.PhysicalColumn = 'CASEID';

-- Check all CHANGES fields
PRINT '';
PRINT '=== All CHANGES fields in contract ===';
SELECT 
    f.FieldKey,
    f.PhysicalColumn,
    f.DataType,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.PhysicalTable = 'CHANGES'
ORDER BY f.PhysicalColumn;

-- Check if CASEID relationship exists
PRINT '';
PRINT '=== CASEID relationships ===';
SELECT 
    ParentTable,
    ParentColumn,
    ChildTable,
    ChildColumn,
    IsActive,
    Source,
    Notes
FROM dbo.MigrationTableRelationships
WHERE ChildTable = 'CHANGES'
  AND ChildColumn = 'CASEID'
  AND IsActive = 1;
