-- Verify CHANGES contract fields
SELECT 
    f.FieldKey,
    f.PhysicalColumn,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.ComponentKey = 'changes'
ORDER BY f.FieldKey;

-- Check if CHANGERECORDID is in the contract
PRINT '';
PRINT '=== CHANGERECORDID Check ===';
IF EXISTS (
    SELECT 1 FROM dbo.MigrationDomainField f
    INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
    WHERE c.ObjectKey = 'captured_data' AND c.ComponentKey = 'changes' AND f.PhysicalColumn = 'CHANGERECORDID'
)
    PRINT 'ERROR: CHANGERECORDID is in the contract - it should be excluded for FK remapping!'
ELSE
    PRINT 'OK: CHANGERECORDID is not in the contract';
