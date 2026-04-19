-- Find duplicate fields in the domain contract
SELECT 
    c.ComponentKey,
    f.PhysicalColumn,
    COUNT(*) AS DuplicateCount
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
GROUP BY c.ComponentKey, f.PhysicalColumn
HAVING COUNT(*) > 1
ORDER BY c.ComponentKey, f.PhysicalColumn;

-- Show all duplicate field details
PRINT '';
PRINT '=== Duplicate Field Details ===';
SELECT 
    c.ComponentKey,
    f.FieldKey,
    f.PhysicalColumn,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.PhysicalColumn IN (
      SELECT PhysicalColumn
      FROM dbo.MigrationDomainField f2
      INNER JOIN dbo.MigrationDomainComponent c2 ON c2.ObjectKey = f2.ObjectKey AND c2.ComponentKey = f2.ComponentKey
      WHERE c2.ObjectKey = 'captured_data'
      GROUP BY c2.ComponentKey, f2.PhysicalColumn
      HAVING COUNT(*) > 1
  )
ORDER BY c.ComponentKey, f.PhysicalColumn, f.FieldKey;
