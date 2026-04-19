-- Set ALL non-FK fields to use ctx() by default if they don't have a generator

-- Update all fields that have NULL or empty generators to use ctx()
UPDATE f
SET f.Notes = 'gen: ctx(' + LOWER(f.PhysicalColumn) + ')'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  -- Not a FK field
  AND f.PhysicalColumn NOT LIKE '%RECORDID'
  AND f.PhysicalColumn NOT LIKE '%CASEID'
  AND NOT (f.PhysicalColumn = 'ID' AND c.PhysicalTable LIKE 'CMF%')
  -- Doesn't have a generator yet
  AND (f.Notes IS NULL OR f.Notes NOT LIKE 'gen:%');

PRINT 'Set all non-FK fields without generators to use ctx() by default';

-- Show fields that still don't have generators (should only be FK fields)
PRINT '';
PRINT '=== Fields Without Generators (should only be FK fields) ===';
SELECT 
    c.ComponentKey,
    f.PhysicalColumn,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND (f.Notes IS NULL OR f.Notes NOT LIKE 'gen:%')
ORDER BY c.ComponentKey, f.PhysicalColumn;

-- Count fields by generator type
PRINT '';
PRINT '=== Generator Type Summary ===';
SELECT 
    CASE 
        WHEN f.Notes LIKE '%ctx(%' THEN 'ctx() - Preserve Original'
        WHEN f.Notes IS NULL THEN 'NULL - FK Field (Auto-Remapped)'
        WHEN f.Notes LIKE '%pool(%' THEN 'pool() - Random Selection'
        WHEN f.Notes LIKE '%literal(%' THEN 'literal() - Fixed Value'
        WHEN f.Notes LIKE '%newguid(%' THEN 'newguid() - New GUID'
        ELSE 'Other'
    END AS GeneratorType,
    COUNT(*) AS FieldCount
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
GROUP BY 
    CASE 
        WHEN f.Notes LIKE '%ctx(%' THEN 'ctx() - Preserve Original'
        WHEN f.Notes IS NULL THEN 'NULL - FK Field (Auto-Remapped)'
        WHEN f.Notes LIKE '%pool(%' THEN 'pool() - Random Selection'
        WHEN f.Notes LIKE '%literal(%' THEN 'literal() - Fixed Value'
        WHEN f.Notes LIKE '%newguid(%' THEN 'newguid() - New GUID'
        ELSE 'Other'
    END
ORDER BY FieldCount DESC;
