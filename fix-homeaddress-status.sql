-- Fix HOMEADDRESSSTATUS to use literal(Active) instead of ctx()
-- The captured data has Concept status which is wrong for home addresses

UPDATE f
SET f.Notes = 'gen: literal(Active)'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.ComponentKey = 'homeaddress'
  AND f.PhysicalColumn = 'HOMEADDRESSSTATUS';

PRINT 'Fixed HOMEADDRESSSTATUS to use literal(Active)';

-- Also fix CONTACTSTATUS and PERSONIDENTIFICATIONSTATUS
UPDATE f
SET f.Notes = 'gen: literal(Active)'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.PhysicalColumn IN ('CONTACTSTATUS', 'PERSONIDENTIFICATIONSTATUS');

PRINT 'Fixed CONTACTSTATUS and PERSONIDENTIFICATIONSTATUS to use literal(Active)';
