SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.RefreshDataDictionary
    @SchemaName SYSNAME = N'dbo',
    @IncludeViews BIT = 0
WITH RECOMPILE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CapturedAt DATETIME2 = SYSUTCDATETIME();

    IF @IncludeViews = 0
    BEGIN
        DELETE c
        FROM dbo.DataDictionaryColumn c
        JOIN dbo.DataDictionaryTable t ON t.TableObjectId = c.TableObjectId
        WHERE t.SchemaName = @SchemaName;

        DELETE ic
        FROM dbo.DataDictionaryIndexColumn ic
        JOIN dbo.DataDictionaryTable t ON t.TableObjectId = ic.TableObjectId
        WHERE t.SchemaName = @SchemaName;

        DELETE i
        FROM dbo.DataDictionaryIndex i
        JOIN dbo.DataDictionaryTable t ON t.TableObjectId = i.TableObjectId
        WHERE t.SchemaName = @SchemaName;

        DELETE FROM dbo.DataDictionaryTable
        WHERE SchemaName = @SchemaName;
    END
    ELSE
    BEGIN
        -- For now treat @IncludeViews same as tables, but include views in the capture.
        DELETE c
        FROM dbo.DataDictionaryColumn c
        JOIN dbo.DataDictionaryTable t ON t.TableObjectId = c.TableObjectId
        WHERE t.SchemaName = @SchemaName;

        DELETE ic
        FROM dbo.DataDictionaryIndexColumn ic
        JOIN dbo.DataDictionaryTable t ON t.TableObjectId = ic.TableObjectId
        WHERE t.SchemaName = @SchemaName;

        DELETE i
        FROM dbo.DataDictionaryIndex i
        JOIN dbo.DataDictionaryTable t ON t.TableObjectId = i.TableObjectId
        WHERE t.SchemaName = @SchemaName;

        DELETE FROM dbo.DataDictionaryTable
        WHERE SchemaName = @SchemaName;
    END

    INSERT INTO dbo.DataDictionaryTable (TableObjectId, SchemaName, TableName, IsView, CreatedAt, ModifiedAt, CapturedAt)
    SELECT
        o.object_id,
        s.name,
        o.name,
        CASE WHEN o.type = 'V' THEN CONVERT(BIT, 1) ELSE CONVERT(BIT, 0) END,
        o.create_date,
        o.modify_date,
        @CapturedAt
    FROM sys.objects o
    JOIN sys.schemas s ON s.schema_id = o.schema_id
    WHERE s.name = @SchemaName
      AND (
            (o.type = 'U')
            OR (@IncludeViews = 1 AND o.type = 'V')
          );

    ;WITH PKCols AS (
        SELECT ic.object_id, ic.column_id
        FROM sys.indexes i
        JOIN sys.index_columns ic
          ON ic.object_id = i.object_id AND ic.index_id = i.index_id
        WHERE i.is_primary_key = 1
    ),
    DefaultDefs AS (
        SELECT dc.parent_object_id AS object_id, dc.parent_column_id AS column_id, dc.definition
        FROM sys.default_constraints dc
    ),
    ComputedDefs AS (
        SELECT cc.object_id, cc.column_id, cc.definition
        FROM sys.computed_columns cc
    )
    INSERT INTO dbo.DataDictionaryColumn (
        TableObjectId, ColumnId, ColumnName,
        TypeName, MaxLength, PrecisionValue, ScaleValue,
        IsNullable, IsIdentity,
        DefaultDefinition,
        IsComputed, ComputedDefinition,
        IsPrimaryKey,
        CollationName,
        CapturedAt
    )
    SELECT
        c.object_id,
        c.column_id,
        c.name,
        ty.name,
        c.max_length,
        CONVERT(INT, c.precision),
        CONVERT(INT, c.scale),
        c.is_nullable,
        c.is_identity,
        dd.definition,
        c.is_computed,
        cd.definition,
        CASE WHEN pk.column_id IS NOT NULL THEN CONVERT(BIT, 1) ELSE CONVERT(BIT, 0) END,
        c.collation_name,
        @CapturedAt
    FROM sys.columns c
    JOIN sys.types ty ON ty.user_type_id = c.user_type_id
    JOIN dbo.DataDictionaryTable t ON t.TableObjectId = c.object_id
    LEFT JOIN PKCols pk ON pk.object_id = c.object_id AND pk.column_id = c.column_id
    LEFT JOIN DefaultDefs dd ON dd.object_id = c.object_id AND dd.column_id = c.column_id
    LEFT JOIN ComputedDefs cd ON cd.object_id = c.object_id AND cd.column_id = c.column_id
    WHERE t.SchemaName = @SchemaName;

    INSERT INTO dbo.DataDictionaryIndex (TableObjectId, IndexId, IndexName, IsUnique, IsPrimaryKey, TypeDesc, FilterDefinition, CapturedAt)
    SELECT
        i.object_id,
        i.index_id,
        i.name,
        i.is_unique,
        i.is_primary_key,
        i.type_desc,
        i.filter_definition,
        @CapturedAt
    FROM sys.indexes i
    JOIN dbo.DataDictionaryTable t ON t.TableObjectId = i.object_id
    WHERE t.SchemaName = @SchemaName
      AND i.index_id > 0
      AND i.is_hypothetical = 0;

    INSERT INTO dbo.DataDictionaryIndexColumn (TableObjectId, IndexId, KeyOrdinal, ColumnId, IsDescending, IsIncluded, CapturedAt)
    SELECT
        ic.object_id,
        ic.index_id,
        ic.key_ordinal,
        ic.column_id,
        ic.is_descending_key,
        ic.is_included_column,
        @CapturedAt
    FROM sys.index_columns ic
    JOIN dbo.DataDictionaryTable t ON t.TableObjectId = ic.object_id
    WHERE t.SchemaName = @SchemaName;

    SELECT
        @SchemaName AS SchemaName,
        COUNT(*) AS TableCount
    FROM dbo.DataDictionaryTable
    WHERE SchemaName = @SchemaName;
END
GO
