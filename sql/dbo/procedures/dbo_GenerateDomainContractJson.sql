SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.GenerateDomainContractJson
    @RunID UNIQUEIDENTIFIER,
    @ObjectKey NVARCHAR(100) = N'individual',
    @ExcludeFrameworkTables BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.EnsureDomainContractDefaults;

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationScenarioRun WHERE RunID = @RunID)
        THROW 50000, N'Unknown RunID.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainObject WHERE ObjectKey = @ObjectKey)
        THROW 50000, N'Unknown ObjectKey.', 1;

    DECLARE @Contract NVARCHAR(MAX);

    ;WITH Obj AS (
        SELECT ObjectKey, DisplayName
        FROM dbo.MigrationDomainObject
        WHERE ObjectKey = @ObjectKey
    ),
    Comps AS (
        SELECT ObjectKey, ComponentKey, DisplayName, MinOccurs, MaxOccurs, SortOrder, PhysicalTable
        FROM dbo.MigrationDomainComponent
        WHERE ObjectKey = @ObjectKey
        AND (@ExcludeFrameworkTables = 0 OR PhysicalTable NOT LIKE 'CMF%')
        AND (@ExcludeFrameworkTables = 0 OR PhysicalTable NOT IN ('CHANGES', 'MUTATION'))
    ),
    Fields AS (
        SELECT
            f.ObjectKey,
            f.ComponentKey,
            f.FieldKey,
            f.DataType,
            f.MaxLength,
            f.PrecisionValue,
            f.ScaleValue,
            f.IsRequired,
            f.EnumKey,
            f.LookupKey,
            f.ExampleValue,
            f.DisplayName
        FROM dbo.MigrationDomainField f
        WHERE f.ObjectKey = @ObjectKey
    ),
    EnumVals AS (
        SELECT e.EnumKey, e.DisplayName,
               (SELECT v.ValueKey AS valueKey, v.DisplayName AS displayName
                FROM dbo.MigrationDomainEnumValue v
                WHERE v.EnumKey = e.EnumKey AND v.IsActive = 1
                ORDER BY v.SortOrder, v.ValueKey
                FOR JSON PATH) AS ValuesJson
        FROM dbo.MigrationDomainEnum e
        WHERE EXISTS (SELECT 1 FROM Fields f WHERE f.EnumKey = e.EnumKey)
    ),
    Lookups AS (
        SELECT l.LookupKey, l.DisplayName
        FROM dbo.MigrationDomainLookup l
        WHERE EXISTS (SELECT 1 FROM Fields f WHERE f.LookupKey = l.LookupKey)
    )
    SELECT @Contract = (
        SELECT
            CONVERT(NVARCHAR(36), @RunID) AS runId,
            N'1.0' AS version,
            JSON_QUERY((SELECT o.ObjectKey AS objectKey, o.DisplayName AS displayName FROM Obj o FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) AS [object],
            (
                SELECT
                    c.ComponentKey AS componentKey,
                    c.DisplayName AS displayName,
                    c.MinOccurs AS minOccurs,
                    ISNULL(c.MaxOccurs, -1) AS maxOccurs,
                    JSON_QUERY((
                        SELECT
                            f.FieldKey AS fieldKey,
                            f.DisplayName AS displayName,
                            f.DataType AS [type],
                            f.IsRequired AS required,
                            f.MaxLength AS maxLength,
                            f.PrecisionValue AS [precision],
                            f.ScaleValue AS scale,
                            f.EnumKey AS enumKey,
                            f.LookupKey AS lookupKey,
                            f.ExampleValue AS example
                        FROM Fields f
                        WHERE f.ObjectKey = c.ObjectKey AND f.ComponentKey = c.ComponentKey
                        ORDER BY f.FieldKey
                        FOR JSON PATH
                    )) AS fields
                FROM Comps c
                ORDER BY c.SortOrder, c.ComponentKey
                FOR JSON PATH
            ) AS components,
            (
                SELECT
                    ev.EnumKey AS enumKey,
                    ev.DisplayName AS displayName,
                    JSON_QUERY(ev.ValuesJson) AS [values]
                FROM EnumVals ev
                ORDER BY ev.EnumKey
                FOR JSON PATH
            ) AS enums,
            (
                SELECT
                    lu.LookupKey AS lookupKey,
                    lu.DisplayName AS displayName
                FROM Lookups lu
                ORDER BY lu.LookupKey
                FOR JSON PATH
            ) AS lookups
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

    SELECT @Contract AS ContractJson;
END
GO
