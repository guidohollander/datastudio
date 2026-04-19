-- Check if generators were preserved or overwritten after contract regeneration
SELECT 
    CASE 
        WHEN f.Notes LIKE '%ctx(%' THEN 'ctx() - Preserve Original'
        WHEN f.Notes LIKE '%pool(%' THEN 'pool() - OVERWRITTEN!'
        WHEN f.Notes LIKE '%literal(%' THEN 'literal() - OVERWRITTEN!'
        WHEN f.Notes LIKE '%random(%' THEN 'random() - OVERWRITTEN!'
        WHEN f.Notes LIKE '%newguid(%' THEN 'newguid()'
        WHEN f.Notes LIKE '%dateRange(%' THEN 'dateRange() - OVERWRITTEN!'
        WHEN f.Notes LIKE '%ageRange(%' THEN 'ageRange() - OVERWRITTEN!'
        WHEN f.Notes LIKE '%weighted(%' THEN 'weighted() - OVERWRITTEN!'
        WHEN f.Notes LIKE '%lookup(%' THEN 'lookup() - OVERWRITTEN!'
        WHEN f.Notes IS NULL OR f.Notes = '' THEN 'NULL/empty'
        ELSE 'Other: ' + LEFT(f.Notes, 50)
    END AS GeneratorType,
    COUNT(*) AS FieldCount
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
GROUP BY 
    CASE 
        WHEN f.Notes LIKE '%ctx(%' THEN 'ctx() - Preserve Original'
        WHEN f.Notes LIKE '%pool(%' THEN 'pool() - OVERWRITTEN!'
        WHEN f.Notes LIKE '%literal(%' THEN 'literal() - OVERWRITTEN!'
        WHEN f.Notes LIKE '%random(%' THEN 'random() - OVERWRITTEN!'
        WHEN f.Notes LIKE '%newguid(%' THEN 'newguid()'
        WHEN f.Notes LIKE '%dateRange(%' THEN 'dateRange() - OVERWRITTEN!'
        WHEN f.Notes LIKE '%ageRange(%' THEN 'ageRange() - OVERWRITTEN!'
        WHEN f.Notes LIKE '%weighted(%' THEN 'weighted() - OVERWRITTEN!'
        WHEN f.Notes LIKE '%lookup(%' THEN 'lookup() - OVERWRITTEN!'
        WHEN f.Notes IS NULL OR f.Notes = '' THEN 'NULL/empty'
        ELSE 'Other: ' + LEFT(f.Notes, 50)
    END
ORDER BY FieldCount DESC;
