-- Check DisplayNames for all components in the captured_data contract
SELECT 
    c.ComponentKey,
    c.DisplayName,
    c.PhysicalTable,
    c.SortOrder,
    COUNT(f.FieldKey) AS FieldCount
FROM dbo.MigrationDomainComponent c
LEFT JOIN dbo.MigrationDomainField f ON f.ObjectKey = c.ObjectKey AND f.ComponentKey = c.ComponentKey
WHERE c.ObjectKey = 'captured_data'
GROUP BY c.ComponentKey, c.DisplayName, c.PhysicalTable, c.SortOrder
ORDER BY c.SortOrder, c.ComponentKey;

-- Also check what relationship info is available
PRINT '';
PRINT '=== Relationships to CHANGES ===';
SELECT 
    r.ParentTable,
    r.ParentColumn,
    r.ChildTable,
    r.ChildColumn,
    r.Notes
FROM dbo.MigrationTableRelationships r
WHERE r.IsActive = 1
  AND (r.ChildTable = 'CHANGES' OR r.ParentTable = 'CHANGES')
ORDER BY r.ParentTable;
