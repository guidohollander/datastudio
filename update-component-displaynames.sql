-- Update DisplayNames to be meaningful descriptions showing case/record type context

UPDATE dbo.MigrationDomainComponent
SET DisplayName = CASE ComponentKey
    WHEN 'changes' THEN 'Changes (Case Change Records)'
    WHEN 'cmfcase' THEN 'CMF Case (Framework Case Container)'
    WHEN 'cmfevent' THEN 'CMF Event (Framework Event)'
    WHEN 'cmfrecord' THEN 'CMF Record (Framework Record Tracking)'
    WHEN 'cmftransition' THEN 'CMF Transition (Framework State Transition)'
    WHEN 'contactinformation' THEN 'Contact Information (Person Registration)'
    WHEN 'homeaddress' THEN 'Home Address (Person Registration)'
    WHEN 'individual' THEN 'Individual (Person Registration)'
    WHEN 'mutation' THEN 'Mutation (Case Mutation Records)'
    WHEN 'personidentification' THEN 'Person Identification (Person Registration)'
    WHEN 'properties' THEN 'Properties (Case Properties)'
    WHEN 'userassignment' THEN 'User Assignment (Workflow)'
    WHEN 'workitem' THEN 'Work Item (Workflow)'
    ELSE DisplayName
END
WHERE ObjectKey = 'captured_data';

PRINT 'Updated DisplayNames with meaningful descriptions';

-- Verify
SELECT 
    ComponentKey,
    DisplayName,
    PhysicalTable
FROM dbo.MigrationDomainComponent
WHERE ObjectKey = 'captured_data'
ORDER BY SortOrder, ComponentKey;
