-- Fix CHANGES.CASEID to have a generator so it gets remapped during replay

PRINT '=== Adding generator to CHANGES.CASEID ===';

UPDATE f
SET f.Notes = 'gen: ctx(caseid)'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.PhysicalTable = 'CHANGES'
  AND f.PhysicalColumn = 'CASEID'
  AND (f.Notes IS NULL OR f.Notes = '');

PRINT 'Added ctx(caseid) generator to CHANGES.CASEID';

-- Verify the fix
PRINT '';
PRINT '=== Verify CHANGES.CASEID now has generator ===';
SELECT 
    f.FieldKey,
    f.PhysicalColumn,
    f.DataType,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.PhysicalTable = 'CHANGES'
  AND f.PhysicalColumn = 'CASEID';

-- Check if there are other FK fields in CHANGES without generators
PRINT '';
PRINT '=== Other FK fields in CHANGES without generators ===';
SELECT 
    f.FieldKey,
    f.PhysicalColumn,
    f.DataType,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.PhysicalTable = 'CHANGES'
  AND (f.PhysicalColumn LIKE '%ID' OR f.PhysicalColumn LIKE '%RECORDID')
  AND (f.Notes IS NULL OR f.Notes = '');
