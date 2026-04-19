-- Verify the contract fixes were applied correctly

PRINT '=== CHANGES Contract Fields ===';
SELECT 
    f.FieldKey,
    f.PhysicalColumn,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.ComponentKey = 'changes'
ORDER BY f.FieldKey;

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

PRINT '';
PRINT '=== HOMEADDRESS Status Field ===';
SELECT 
    f.FieldKey,
    f.PhysicalColumn,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.ComponentKey = 'homeaddress'
  AND f.PhysicalColumn = 'HOMEADDRESSSTATUS';

PRINT '';
PRINT '=== Key Findings ===';
PRINT 'CASEID should NOT be in CHANGES or MUTATION contracts (should be remapped by ReplayScenarioRun)';
PRINT 'HOMEADDRESSSTATUS should use literal(Active)';
