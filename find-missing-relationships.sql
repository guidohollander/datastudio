-- Find contract fields that look like FKs but have no matching relationship in MigrationTableRelationships

PRINT '=== Contract FK fields WITHOUT relationship entries ===';
SELECT 
    c.ComponentKey,
    c.PhysicalTable,
    f.PhysicalColumn,
    f.DataType,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.MigrationTableRelationships r
      WHERE r.ChildTable = c.PhysicalTable
        AND r.ChildColumn = f.PhysicalColumn
        AND r.IsActive = 1
  )
  -- Only show fields that look like FKs
  AND (f.PhysicalColumn LIKE '%ID' OR f.PhysicalColumn LIKE '%RECORDID' OR f.PhysicalColumn LIKE '%CASEID')
ORDER BY c.PhysicalTable, f.PhysicalColumn;

PRINT '';
PRINT '=== Contract FK fields WITH relationship entries ===';
SELECT 
    c.ComponentKey,
    c.PhysicalTable,
    f.PhysicalColumn,
    r.ParentTable,
    r.ParentColumn
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
INNER JOIN dbo.MigrationTableRelationships r ON r.ChildTable = c.PhysicalTable AND r.ChildColumn = f.PhysicalColumn AND r.IsActive = 1
WHERE c.ObjectKey = 'captured_data'
ORDER BY c.PhysicalTable, f.PhysicalColumn;

PRINT '';
PRINT '=== All relationships for captured tables ===';
SELECT 
    r.ParentTable,
    r.ParentColumn,
    r.ChildTable,
    r.ChildColumn,
    r.Source
FROM dbo.MigrationTableRelationships r
WHERE r.IsActive = 1
  AND r.ChildTable IN (SELECT PhysicalTable FROM dbo.MigrationDomainComponent WHERE ObjectKey = 'captured_data')
ORDER BY r.ChildTable, r.ChildColumn;
