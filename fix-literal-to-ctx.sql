-- Fix fields with literal() generators to use ctx() to preserve original values
-- Users can explicitly change to literal() if they want a fixed value

UPDATE f
SET f.Notes = 'gen: ctx(' + LOWER(f.PhysicalColumn) + ')'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.Notes LIKE '%literal(%'
  -- Don't change FK fields
  AND f.PhysicalColumn NOT LIKE '%RECORDID'
  AND f.PhysicalColumn NOT LIKE '%CASEID'
  AND NOT (f.PhysicalColumn = 'ID' AND c.PhysicalTable LIKE 'CMF%');

PRINT 'Fixed literal() fields to use ctx() to preserve original values';

-- Show what was changed
PRINT '';
PRINT '=== Fields Changed from literal() to ctx() ===';
SELECT 
    c.ComponentKey,
    f.PhysicalColumn,
    f.ExampleValue,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.PhysicalColumn IN ('CONTACTSOURCE', 'HOMEADDRESSSOURCE', 'PERSONIDENTIFICATIONSOURCE', 'INDIVIDUALSOURCE')
ORDER BY c.ComponentKey, f.PhysicalColumn;
