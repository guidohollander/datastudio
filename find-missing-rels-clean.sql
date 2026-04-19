-- Find contract fields that end with ID/CASEID/RECORDID but have NO relationship entry
PRINT '=== FK-like fields WITHOUT relationships ===';
SELECT 
    c.PhysicalTable + '.' + f.PhysicalColumn AS [Field],
    f.DataType
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND (f.PhysicalColumn LIKE '%ID' OR f.PhysicalColumn LIKE '%RECORDID' OR f.PhysicalColumn LIKE '%CASEID')
  AND NOT EXISTS (
      SELECT 1 FROM dbo.MigrationTableRelationships r
      WHERE r.ChildTable = c.PhysicalTable AND r.ChildColumn = f.PhysicalColumn AND r.IsActive = 1
  )
ORDER BY c.PhysicalTable, f.PhysicalColumn;

PRINT '';
PRINT '=== FK-like fields WITH relationships ===';
SELECT 
    c.PhysicalTable + '.' + f.PhysicalColumn AS [Field],
    r.ParentTable + '.' + r.ParentColumn AS [MappedFrom]
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
INNER JOIN dbo.MigrationTableRelationships r ON r.ChildTable = c.PhysicalTable AND r.ChildColumn = f.PhysicalColumn AND r.IsActive = 1
WHERE c.ObjectKey = 'captured_data'
ORDER BY c.PhysicalTable, f.PhysicalColumn;
