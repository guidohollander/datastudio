-- Change all status fields from literal() to ctx() to preserve original values by default

UPDATE f
SET f.Notes = 'gen: ctx(' + LOWER(f.PhysicalColumn) + ')'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND (f.PhysicalColumn LIKE '%STATUS' OR f.PhysicalColumn = 'RESULTS')
  AND (f.Notes LIKE '%literal%' OR f.Notes IS NULL);

PRINT 'Updated all status fields to use ctx() instead of literal()';

-- Verify all status fields
PRINT '';
PRINT '=== All Status Fields ===';
SELECT 
    c.ComponentKey,
    f.PhysicalColumn,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND (f.PhysicalColumn LIKE '%STATUS' OR f.PhysicalColumn = 'RESULTS')
ORDER BY c.ComponentKey, f.PhysicalColumn;
