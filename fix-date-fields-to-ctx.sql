-- Change all date fields from dateRange() to ctx() to preserve original values by default

UPDATE f
SET f.Notes = 'gen: ctx(' + LOWER(f.PhysicalColumn) + ')'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.Notes LIKE '%dateRange%';

PRINT 'Updated all date fields to use ctx() instead of dateRange()';

-- Verify date fields
PRINT '';
PRINT '=== Date Fields Updated ===';
SELECT 
    c.ComponentKey,
    f.PhysicalColumn,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND (f.PhysicalColumn LIKE '%DATE%' OR f.PhysicalColumn LIKE '%BIRTH%')
ORDER BY c.ComponentKey, f.PhysicalColumn;
