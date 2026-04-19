-- Check fields that have NULL example values but non-ctx() generators
SELECT 
    c.ComponentKey,
    f.PhysicalColumn,
    f.ExampleValue,
    f.Notes AS Generator
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.ExampleValue IS NULL
  AND f.Notes LIKE 'gen:%'
  AND f.Notes NOT LIKE '%ctx(%'
  AND f.PhysicalColumn NOT LIKE '%RECORDID'
  AND f.PhysicalColumn NOT LIKE '%CASEID'
ORDER BY c.ComponentKey, f.PhysicalColumn;
