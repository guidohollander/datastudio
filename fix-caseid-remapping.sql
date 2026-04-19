-- CASEID should not be in the contract for CHANGES and MUTATION
-- It should be handled by FK remapping in ReplayScenarioRun

-- Remove CASEID from CHANGES contract
DELETE FROM dbo.MigrationDomainField
WHERE ObjectKey = 'captured_data'
  AND ComponentKey = 'changes'
  AND PhysicalColumn = 'CASEID';

PRINT 'Removed CASEID from CHANGES contract';

-- Remove CASEID from MUTATION contract
DELETE FROM dbo.MigrationDomainField
WHERE ObjectKey = 'captured_data'
  AND ComponentKey = 'mutation'
  AND PhysicalColumn = 'CASEID';

PRINT 'Removed CASEID from MUTATION contract';

-- Verify
PRINT '';
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
