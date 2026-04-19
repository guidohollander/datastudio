-- Remove duplicate relationships, keep one per unique combo
WITH Dups AS (
    SELECT RelationshipID,
           ROW_NUMBER() OVER (PARTITION BY ParentTable, ParentColumn, ChildTable, ChildColumn ORDER BY RelationshipID) AS rn
    FROM dbo.MigrationTableRelationships
    WHERE IsActive = 1
)
DELETE FROM dbo.MigrationTableRelationships
WHERE RelationshipID IN (SELECT RelationshipID FROM Dups WHERE rn > 1);

PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' duplicate relationships removed';

-- Verify clean results
PRINT '';
PRINT '=== Clean FK fields WITH relationships ===';
SELECT 
    c.PhysicalTable + '.' + f.PhysicalColumn AS Field,
    STRING_AGG(r.ParentTable + '.' + r.ParentColumn, ' / ') AS MappedFrom
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
INNER JOIN dbo.MigrationTableRelationships r ON r.ChildTable = c.PhysicalTable AND r.ChildColumn = f.PhysicalColumn AND r.IsActive = 1
WHERE c.ObjectKey = 'captured_data'
GROUP BY c.PhysicalTable, f.PhysicalColumn
ORDER BY c.PhysicalTable, f.PhysicalColumn;
