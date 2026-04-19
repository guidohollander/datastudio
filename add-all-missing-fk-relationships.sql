-- Add all missing FK relationships for captured tables

-- CMFRECORD.CASEID -> CMFCASE.ID (already exists from earlier but may have been removed)
IF NOT EXISTS (SELECT 1 FROM dbo.MigrationTableRelationships WHERE ChildTable='CMFRECORD' AND ChildColumn='CASEID' AND ParentTable='CMFCASE' AND IsActive=1)
    INSERT INTO dbo.MigrationTableRelationships (ParentTable, ParentColumn, ChildTable, ChildColumn, IsActive, Source, Notes)
    VALUES ('CMFCASE', 'ID', 'CMFRECORD', 'CASEID', 1, 'Analysis', 'CMFRECORD belongs to CMFCASE');

-- CMFEVENT.CASEID -> CMFCASE.ID (framework event belongs to a case)
IF NOT EXISTS (SELECT 1 FROM dbo.MigrationTableRelationships WHERE ChildTable='CMFEVENT' AND ChildColumn='CASEID' AND ParentTable='CMFCASE' AND IsActive=1)
    INSERT INTO dbo.MigrationTableRelationships (ParentTable, ParentColumn, ChildTable, ChildColumn, IsActive, Source, Notes)
    VALUES ('CMFCASE', 'ID', 'CMFEVENT', 'CASEID', 1, 'Analysis', 'CMFEVENT belongs to CMFCASE');

-- CMFTRANSITION.CASEID -> CMFCASE.ID (framework transition belongs to a case)
IF NOT EXISTS (SELECT 1 FROM dbo.MigrationTableRelationships WHERE ChildTable='CMFTRANSITION' AND ChildColumn='CASEID' AND ParentTable='CMFCASE' AND IsActive=1)
    INSERT INTO dbo.MigrationTableRelationships (ParentTable, ParentColumn, ChildTable, ChildColumn, IsActive, Source, Notes)
    VALUES ('CMFCASE', 'ID', 'CMFTRANSITION', 'CASEID', 1, 'Analysis', 'CMFTRANSITION belongs to CMFCASE');

-- SC_USERASSIGNMENT.CASEID -> CMFCASE.ID (user assignment belongs to a case)
IF NOT EXISTS (SELECT 1 FROM dbo.MigrationTableRelationships WHERE ChildTable='SC_USERASSIGNMENT' AND ChildColumn='CASEID' AND ParentTable='CMFCASE' AND IsActive=1)
    INSERT INTO dbo.MigrationTableRelationships (ParentTable, ParentColumn, ChildTable, ChildColumn, IsActive, Source, Notes)
    VALUES ('CMFCASE', 'ID', 'SC_USERASSIGNMENT', 'CASEID', 1, 'Analysis', 'SC_USERASSIGNMENT belongs to CMFCASE');

-- SC_WORKITEM.CASEID -> CMFCASE.ID (work item belongs to a case)
IF NOT EXISTS (SELECT 1 FROM dbo.MigrationTableRelationships WHERE ChildTable='SC_WORKITEM' AND ChildColumn='CASEID' AND ParentTable='CMFCASE' AND IsActive=1)
    INSERT INTO dbo.MigrationTableRelationships (ParentTable, ParentColumn, ChildTable, ChildColumn, IsActive, Source, Notes)
    VALUES ('CMFCASE', 'ID', 'SC_WORKITEM', 'CASEID', 1, 'Analysis', 'SC_WORKITEM belongs to CMFCASE');

PRINT 'Added missing FK relationships';

-- Verify
PRINT '';
PRINT '=== All FK fields now WITH relationships ===';
SELECT 
    c.PhysicalTable + '.' + f.PhysicalColumn AS [Field],
    r.ParentTable + '.' + r.ParentColumn AS [MappedFrom]
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
INNER JOIN dbo.MigrationTableRelationships r ON r.ChildTable = c.PhysicalTable AND r.ChildColumn = f.PhysicalColumn AND r.IsActive = 1
WHERE c.ObjectKey = 'captured_data'
ORDER BY c.PhysicalTable, f.PhysicalColumn;

PRINT '';
PRINT '=== FK-like fields still WITHOUT relationships ===';
SELECT 
    c.PhysicalTable + '.' + f.PhysicalColumn AS [Field],
    f.DataType
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND (f.PhysicalColumn LIKE '%ID' OR f.PhysicalColumn LIKE '%RECORDID' OR f.PhysicalColumn LIKE '%CASEID' OR f.PhysicalColumn LIKE '%GUID')
  AND NOT EXISTS (
      SELECT 1 FROM dbo.MigrationTableRelationships r
      WHERE r.ChildTable = c.PhysicalTable AND r.ChildColumn = f.PhysicalColumn AND r.IsActive = 1
  )
ORDER BY c.PhysicalTable, f.PhysicalColumn;
