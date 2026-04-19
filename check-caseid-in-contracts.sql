-- Check which tables have CASEID in their contract fields
PRINT '=== Tables with CASEID in contract ===';
SELECT 
    c.PhysicalTable,
    f.PhysicalColumn,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.PhysicalColumn = 'CASEID'
ORDER BY c.PhysicalTable;

-- Check which tables SHOULD have CASEID but don't
PRINT '';
PRINT '=== Tables that have CASEID column but NOT in contract ===';
SELECT DISTINCT 
    col.TableName,
    col.ColumnName
FROM (
    SELECT OBJECT_NAME(c.TableObjectId) AS TableName, c.ColumnName
    FROM dbo.DataDictionaryColumn c
    WHERE c.ColumnName = 'CASEID'
) col
WHERE col.TableName IN (SELECT PhysicalTable FROM dbo.MigrationDomainComponent WHERE ObjectKey = 'captured_data')
  AND NOT EXISTS (
    SELECT 1 FROM dbo.MigrationDomainField f
    INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
    WHERE c.ObjectKey = 'captured_data' AND c.PhysicalTable = col.TableName AND f.PhysicalColumn = 'CASEID'
  )
ORDER BY col.TableName;

-- Also check the relationship entries we just added
PRINT '';
PRINT '=== Relationship entries we added ===';
SELECT 
    r.ParentTable + '.' + r.ParentColumn AS Parent,
    r.ChildTable + '.' + r.ChildColumn AS Child,
    r.Source,
    r.Notes
FROM dbo.MigrationTableRelationships r
WHERE r.Source = 'Analysis'
  AND r.IsActive = 1
ORDER BY r.ChildTable;
