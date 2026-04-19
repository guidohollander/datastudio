-- Change MUTATION status fields from literal() to ctx() to preserve original values

UPDATE f
SET f.Notes = 'gen: ctx(' + LOWER(f.PhysicalColumn) + ')'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.ComponentKey = 'mutation'
  AND f.PhysicalColumn = 'CHANGESTATUS';

PRINT 'Updated MUTATION CHANGESTATUS to use ctx()';

-- Verify
PRINT '';
PRINT '=== MUTATION Contract Fields ===';
SELECT 
    f.FieldKey,
    f.PhysicalColumn,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.ComponentKey = 'mutation'
ORDER BY f.FieldKey;
