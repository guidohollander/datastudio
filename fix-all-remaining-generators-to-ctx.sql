-- Fix ALL remaining non-ctx() generators to use ctx() by default
-- This ensures ALL fields preserve original values unless user explicitly changes them

-- First, let's see what we're dealing with
PRINT '=== Fields with non-ctx() generators (excluding FK fields) ===';
SELECT 
    c.ComponentKey,
    f.PhysicalColumn,
    f.ExampleValue,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.Notes LIKE 'gen:%'
  AND f.Notes NOT LIKE '%ctx(%'
  -- Exclude FK fields
  AND f.PhysicalColumn NOT LIKE '%RECORDID'
  AND f.PhysicalColumn NOT LIKE '%CASEID'
  AND NOT (f.PhysicalColumn = 'ID' AND c.PhysicalTable LIKE 'CMF%')
ORDER BY c.ComponentKey, f.PhysicalColumn;

PRINT '';
PRINT '=== Fixing ALL non-ctx() generators to ctx() ===';

-- Update ALL non-ctx() generators to use ctx()
UPDATE f
SET f.Notes = 'gen: ctx(' + LOWER(f.PhysicalColumn) + ')'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.Notes LIKE 'gen:%'
  AND f.Notes NOT LIKE '%ctx(%'
  -- Exclude FK fields (they should remain NULL for auto-remapping)
  AND f.PhysicalColumn NOT LIKE '%RECORDID'
  AND f.PhysicalColumn NOT LIKE '%CASEID'
  AND NOT (f.PhysicalColumn = 'ID' AND c.PhysicalTable LIKE 'CMF%');

PRINT 'Fixed all non-ctx() generators to use ctx()';

-- Verify: Show generator type summary
PRINT '';
PRINT '=== Generator Type Summary After Fix ===';
SELECT 
    CASE 
        WHEN f.Notes LIKE '%ctx(%' THEN 'ctx() - Preserve Original'
        WHEN f.Notes IS NULL THEN 'NULL - FK Field (Auto-Remapped)'
        WHEN f.Notes LIKE '%pool(%' THEN 'pool() - Random Selection'
        WHEN f.Notes LIKE '%literal(%' THEN 'literal() - Fixed Value'
        WHEN f.Notes LIKE '%random(%' THEN 'random() - Random Number'
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
        WHEN f.Notes LIKE '%random(%' THEN 'random() - Random Number'
        WHEN f.Notes LIKE '%newguid(%' THEN 'newguid() - New GUID'
        ELSE 'Other'
    END
ORDER BY FieldCount DESC;
