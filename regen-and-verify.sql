-- Regenerate contract and verify CASEID is now included for all tables

DECLARE @RunID UNIQUEIDENTIFIER;
SELECT TOP 1 @RunID = RunID
FROM dbo.MigrationScenarioRun
WHERE EndedAt IS NOT NULL
ORDER BY StartedAt DESC;

EXEC dbo.GenerateContractFromCapture @RunID = @RunID, @ObjectKey = 'captured_data', @ObjectDisplayName = 'Captured Business Data';

-- Verify CASEID is now in contract for all tables
PRINT '';
PRINT '=== Tables with CASEID in contract after regeneration ===';
SELECT 
    c.PhysicalTable,
    f.PhysicalColumn,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.PhysicalColumn = 'CASEID'
ORDER BY c.PhysicalTable;

-- Verify FK fields WITH relationships
PRINT '';
PRINT '=== FK fields WITH relationships ===';
SELECT 
    c.PhysicalTable + '.' + f.PhysicalColumn AS [Field],
    r.ParentTable + '.' + r.ParentColumn AS [MappedFrom]
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
INNER JOIN dbo.MigrationTableRelationships r ON r.ChildTable = c.PhysicalTable AND r.ChildColumn = f.PhysicalColumn AND r.IsActive = 1
WHERE c.ObjectKey = 'captured_data'
ORDER BY c.PhysicalTable, f.PhysicalColumn;
