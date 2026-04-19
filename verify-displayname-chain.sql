-- Verify the DisplayName generation works end-to-end

-- First, get the latest run ID
DECLARE @RunID UNIQUEIDENTIFIER;
SELECT TOP 1 @RunID = RunID
FROM dbo.MigrationScenarioRun
WHERE EndedAt IS NOT NULL
ORDER BY StartedAt DESC;

-- Re-generate the contract (simulates what the UI does on "Load Contract")
EXEC dbo.GenerateContractFromCapture @RunID = @RunID, @ObjectKey = 'captured_data', @ObjectDisplayName = 'Captured Business Data';

-- Now verify the DisplayNames
PRINT '';
PRINT '=== Component DisplayNames After Regeneration ===';
SELECT 
    c.ComponentKey,
    c.DisplayName,
    c.PhysicalTable
FROM dbo.MigrationDomainComponent c
WHERE c.ObjectKey = 'captured_data'
ORDER BY c.SortOrder, c.ComponentKey;
