-- Fix fields with NULL example values to use ctx() instead of other generators
-- This ensures NULL values are preserved unless user explicitly changes the generator

UPDATE f
SET f.Notes = 'gen: ctx(' + LOWER(f.PhysicalColumn) + ')'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.ExampleValue IS NULL
  AND f.Notes LIKE 'gen:%'
  AND f.Notes NOT LIKE '%ctx(%'
  -- Don't change FK fields (they should remain NULL for auto-remapping)
  AND f.PhysicalColumn NOT LIKE '%RECORDID'
  AND f.PhysicalColumn NOT LIKE '%CASEID'
  AND NOT (f.PhysicalColumn = 'ID' AND c.PhysicalTable LIKE 'CMF%');

PRINT 'Fixed NULL-valued fields to use ctx() to preserve original NULL values';

-- Show what was changed
PRINT '';
PRINT '=== Fields Changed to ctx() ===';
SELECT 
    c.ComponentKey,
    f.PhysicalColumn,
    f.ExampleValue,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.ExampleValue IS NULL
  AND f.Notes LIKE '%ctx(%'
ORDER BY c.ComponentKey, f.PhysicalColumn;
