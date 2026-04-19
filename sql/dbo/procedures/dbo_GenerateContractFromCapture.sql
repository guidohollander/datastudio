SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.GenerateContractFromCapture
    @RunID UNIQUEIDENTIFIER,
    @ObjectKey NVARCHAR(100) = NULL,
    @ObjectDisplayName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Default object key to run ID if not provided
    IF @ObjectKey IS NULL
        SET @ObjectKey = LOWER(REPLACE(CONVERT(NVARCHAR(36), @RunID), '-', '_'));

    -- Default display name
    IF @ObjectDisplayName IS NULL
        SET @ObjectDisplayName = N'Captured Data';

    -- Ensure domain object exists
    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainObject WHERE ObjectKey = @ObjectKey)
    BEGIN
        INSERT INTO dbo.MigrationDomainObject (ObjectKey, DisplayName)
        VALUES (@ObjectKey, @ObjectDisplayName);
    END

    -- Get all captured tables (no exclusions for internal use)
    DECLARE @TableName SYSNAME;
    DECLARE @SortOrder INT = 1;

    DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT r.TableName
        FROM dbo.MigrationScenarioRow r
        WHERE r.RunID = @RunID
          -- Only exclude system/migration tracking tables
          AND r.TableName NOT LIKE 'qrtz_%'
          AND r.TableName NOT LIKE 'sys%'
          AND r.TableName NOT LIKE 'DataDictionary%'
          AND r.TableName NOT LIKE 'Migration%'
        ORDER BY r.TableName;

    OPEN table_cursor;
    FETCH NEXT FROM table_cursor INTO @TableName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Create component key from table name (lowercase, remove prefixes)
        DECLARE @ComponentKey NVARCHAR(100) = LOWER(
            REPLACE(
                REPLACE(
                    REPLACE(@TableName, 'SC_PERSONREGISTRATION_', ''),
                    'SC_', ''
                ),
                '_', ''
            )
        );

        -- Create display name from table name with meaningful context
        DECLARE @ComponentDisplayName NVARCHAR(200);
        SET @ComponentDisplayName = CASE @TableName
            WHEN 'CHANGES' THEN 'Changes (Case Change Records)'
            WHEN 'CMFCASE' THEN 'CMF Case (Framework Case)'
            WHEN 'CMFEVENT' THEN 'CMF Event (Framework Event)'
            WHEN 'CMFRECORD' THEN 'CMF Record (Framework Record Tracking)'
            WHEN 'CMFTRANSITION' THEN 'CMF Transition (State Transition)'
            WHEN 'MUTATION' THEN 'Mutation (Case Mutation Records)'
            WHEN 'SC_PERSONREGISTRATION_CONTACTINFORMATION' THEN 'Contact Information (Person Registration)'
            WHEN 'SC_PERSONREGISTRATION_HOMEADDRESS' THEN 'Home Address (Person Registration)'
            WHEN 'SC_PERSONREGISTRATION_INDIVIDUAL' THEN 'Individual (Person Registration)'
            WHEN 'SC_PERSONREGISTRATION_PERSONIDENTIFICATION' THEN 'Person Identification (Person Registration)'
            WHEN 'SC_PERSONREGISTRATION_PROPERTIES' THEN 'Properties (Case Properties)'
            WHEN 'SC_USERASSIGNMENT' THEN 'User Assignment (Workflow)'
            WHEN 'SC_WORKITEM' THEN 'Work Item (Workflow)'
            ELSE REPLACE(REPLACE(REPLACE(@TableName, 'SC_PERSONREGISTRATION_', ''), 'SC_', ''), '_', ' ')
        END;

        -- Determine cardinality based on table name patterns
        DECLARE @MinOccurs INT = 1;
        DECLARE @MaxOccurs INT = 1;

        -- Tables with multiple instances
        IF @TableName LIKE '%ADDRESS%' OR @TableName LIKE '%CONTACT%' OR @TableName LIKE '%IDENTIFICATION%'
        BEGIN
            SET @MinOccurs = 0;
            SET @MaxOccurs = NULL; -- Unlimited
        END

        -- Insert or update component
        IF EXISTS (SELECT 1 FROM dbo.MigrationDomainComponent WHERE ObjectKey = @ObjectKey AND ComponentKey = @ComponentKey)
        BEGIN
            UPDATE dbo.MigrationDomainComponent
            SET DisplayName = @ComponentDisplayName,
                PhysicalTable = @TableName,
                MinOccurs = @MinOccurs,
                MaxOccurs = @MaxOccurs,
                SortOrder = @SortOrder
            WHERE ObjectKey = @ObjectKey AND ComponentKey = @ComponentKey;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.MigrationDomainComponent (ObjectKey, ComponentKey, DisplayName, PhysicalTable, MinOccurs, MaxOccurs, SortOrder)
            VALUES (@ObjectKey, @ComponentKey, @ComponentDisplayName, @TableName, @MinOccurs, @MaxOccurs, @SortOrder);
        END

        -- Get columns for this table
        DECLARE @ColumnName SYSNAME;
        DECLARE @DataType NVARCHAR(128);
        DECLARE @MaxLength INT;
        DECLARE @IsNullable BIT;
        DECLARE @IsPrimaryKey BIT;

        DECLARE column_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT 
                c.ColumnName,
                c.TypeName,
                c.MaxLength,
                c.IsNullable,
                c.IsPrimaryKey
            FROM dbo.DataDictionaryColumn c
            WHERE c.TableObjectId = OBJECT_ID(@TableName)
              -- Exclude primary keys (auto-managed)
              AND c.IsPrimaryKey = 0
              -- Exclude foreign keys (auto-managed by relationships)
              -- BUT keep columns that are registered in MigrationTableRelationships (needed for replay FK remapping)
              AND (c.ColumnName NOT IN (
                      SELECT DISTINCT rc.ChildColumn 
                      FROM dbo.DataDictionaryRelationshipCandidate rc 
                      WHERE rc.ChildTable = @TableName
                  )
                  OR @TableName IN ('CHANGES', 'MUTATION')
                  OR c.ColumnName IN (
                      SELECT DISTINCT r.ChildColumn
                      FROM dbo.MigrationTableRelationships r
                      WHERE r.ChildTable = @TableName AND r.IsActive = 1
                  ))
              -- Exclude *RECORDID pattern EXCEPT for CHANGES and MUTATION tables which need these FKs
              -- BUT also exclude CHANGERECORDID and MUTATIONRECORDID since they are FKs that need remapping
              AND (c.ColumnName NOT LIKE '%RECORDID' 
                   OR (@TableName IN ('CHANGES', 'MUTATION') AND c.ColumnName NOT IN ('CHANGERECORDID', 'MUTATIONRECORDID', 'CORRECTEDRECORDID')))
              -- Exclude technical/system columns (but keep CASEID for all tables that need FK remapping)
              AND (c.ColumnName NOT IN ('DELETED', 'V20230401', 'REVISION', 'DATECREATED', 'DATEMODIFIED', 'CREATEDBY', 'MODIFIEDBY', 'EXECUTABLEACTIVITIES', 'PERFORMEDACTIVITIES')
                   OR c.ColumnName = 'CASEID')
              -- Exclude system field suffixes
              AND c.ColumnName NOT LIKE '%CREATEDBY'
              AND c.ColumnName NOT LIKE '%DATECREATED'
              AND c.ColumnName NOT LIKE '%DATEOFRECEIPT'
              -- Exclude timestamp columns
              AND c.ColumnName NOT LIKE '%TIMECREATED'
              AND c.ColumnName NOT LIKE '%TIMEEXPIRED'
              AND c.ColumnName NOT LIKE '%DATEEXPIRED'
              AND c.ColumnName NOT LIKE '%EXPIREDBY'
              AND c.ColumnName NOT LIKE '%EXPIRATIONDATE'
              AND c.ColumnName NOT LIKE '%EXPIRATIONTIME'
              -- Exclude status note fields (usually long text)
              AND c.ColumnName NOT LIKE '%STATUSNOTE'
              -- Exclude search fields (derived)
              AND c.ColumnName NOT LIKE 'SEARCH%'
            ORDER BY c.ColumnId;

        OPEN column_cursor;
        FETCH NEXT FROM column_cursor INTO @ColumnName, @DataType, @MaxLength, @IsNullable, @IsPrimaryKey;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Create field key from column name (lowercase)
            DECLARE @FieldKey NVARCHAR(100) = LOWER(@ColumnName);

            -- Default generator: ALWAYS use ctx(fieldname) to preserve original values
            -- User can explicitly change to other generators if they want to generate new values
            DECLARE @DefaultGenerator NVARCHAR(500) = 'gen: ctx(' + @FieldKey + ')';
            DECLARE @ColumnNameUpper NVARCHAR(200) = UPPER(@ColumnName);

            -- Map SQL data types to domain types
            DECLARE @DomainDataType NVARCHAR(50);
            IF @DataType IN ('nvarchar', 'varchar', 'char', 'nchar', 'text', 'ntext')
                SET @DomainDataType = 'string';
            ELSE IF @DataType IN ('int', 'bigint', 'smallint', 'tinyint')
                SET @DomainDataType = 'integer';
            ELSE IF @DataType IN ('decimal', 'numeric', 'float', 'real', 'money', 'smallmoney')
                SET @DomainDataType = 'number';
            ELSE IF @DataType IN ('date', 'datetime', 'datetime2', 'smalldatetime')
                SET @DomainDataType = 'date';
            ELSE IF @DataType = 'bit'
                SET @DomainDataType = 'boolean';
            ELSE IF @DataType = 'uniqueidentifier'
                SET @DomainDataType = 'string';
            ELSE
                SET @DomainDataType = 'string';

            -- Get example value from captured data
            DECLARE @ExampleValue NVARCHAR(MAX);
            DECLARE @ExampleJson NVARCHAR(MAX);
            
            SELECT TOP 1 @ExampleJson = r.RowJson
            FROM dbo.MigrationScenarioRow r
            WHERE r.RunID = @RunID AND r.TableName = @TableName;

            IF @ExampleJson IS NOT NULL
            BEGIN
                SET @ExampleValue = JSON_VALUE(@ExampleJson, '$.' + @ColumnName);
            END

            -- Insert or update field
            IF EXISTS (SELECT 1 FROM dbo.MigrationDomainField WHERE ObjectKey = @ObjectKey AND ComponentKey = @ComponentKey AND FieldKey = @FieldKey)
            BEGIN
                UPDATE dbo.MigrationDomainField
                SET PhysicalColumn = @ColumnName,
                    DataType = @DomainDataType,
                    MaxLength = @MaxLength,
                    IsRequired = CASE WHEN @IsNullable = 0 THEN 1 ELSE 0 END,
                    ExampleValue = @ExampleValue,
                    Notes = CASE WHEN Notes IS NULL OR Notes = '' THEN @DefaultGenerator ELSE Notes END
                WHERE ObjectKey = @ObjectKey AND ComponentKey = @ComponentKey AND FieldKey = @FieldKey;
            END
            ELSE
            BEGIN
                INSERT INTO dbo.MigrationDomainField (
                    ObjectKey, ComponentKey, FieldKey, PhysicalColumn, 
                    DataType, MaxLength, IsRequired, ExampleValue, Notes
                )
                VALUES (
                    @ObjectKey, @ComponentKey, @FieldKey, @ColumnName,
                    @DomainDataType, @MaxLength, CASE WHEN @IsNullable = 0 THEN 1 ELSE 0 END, @ExampleValue, @DefaultGenerator
                );
            END

            FETCH NEXT FROM column_cursor INTO @ColumnName, @DataType, @MaxLength, @IsNullable, @IsPrimaryKey;
        END

        CLOSE column_cursor;
        DEALLOCATE column_cursor;

        SET @SortOrder += 1;
        FETCH NEXT FROM table_cursor INTO @TableName;
    END

    CLOSE table_cursor;
    DEALLOCATE table_cursor;

    -- Return the generated object key
    SELECT @ObjectKey AS ObjectKey, @ObjectDisplayName AS DisplayName;
END
GO
