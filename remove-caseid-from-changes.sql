-- Remove CASEID from CHANGES contract (it should be remapped by ReplayScenarioRun)
DELETE FROM dbo.MigrationDomainField
WHERE ObjectKey = 'captured_data'
  AND ComponentKey = 'changes'
  AND PhysicalColumn = 'CASEID';

PRINT 'Removed CASEID from CHANGES contract';

-- Also remove from MUTATION
DELETE FROM dbo.MigrationDomainField
WHERE ObjectKey = 'captured_data'
  AND ComponentKey = 'mutation'
  AND PhysicalColumn = 'CASEID';

PRINT 'Removed CASEID from MUTATION contract';

-- Verify
PRINT '';
PRINT '=== CHANGES Contract After Cleanup ===';
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
PRINT '=== MUTATION Contract After Cleanup ===';
SELECT 
    f.FieldKey,
    f.PhysicalColumn,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.ComponentKey = 'mutation'
ORDER BY f.FieldKey;
