SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.ReplayDomainFast
    @SourceRunID UNIQUEIDENTIFIER,
    @ObjectKey NVARCHAR(100),
    @Times INT = 1,
    @Notes NVARCHAR(2000) = NULL,
    @Commit BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate inputs
    IF @SourceRunID IS NULL
        THROW 50000, N'SourceRunID is required.', 1;
    
    IF @ObjectKey IS NULL OR @ObjectKey = N''
        THROW 50000, N'ObjectKey is required.', 1;
    
    IF @Times < 1 OR @Times > 1000
        THROW 50000, N'Times must be between 1 and 1000.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.MigrationDomainField
        WHERE ObjectKey = @ObjectKey
    )
        THROW 50000, N'ObjectKey has no configured domain fields.', 1;

    -- Get field configurations
    DECLARE @Fields TABLE (
        ComponentKey NVARCHAR(100),
        FieldKey NVARCHAR(100),
        PhysicalTable SYSNAME,
        PhysicalColumn SYSNAME,
        Generator NVARCHAR(MAX),
        IsFK BIT,
        SortOrder INT
    );

    -- Fetch FK relationships
    DECLARE @FKFields TABLE (TableName SYSNAME, ColumnName SYSNAME);
    INSERT INTO @FKFields (TableName, ColumnName)
    SELECT DISTINCT ChildTable, ChildColumn
    FROM dbo.MigrationTableRelationships WHERE IsActive = 1
    UNION
    SELECT DISTINCT ChildTable, ChildColumn
    FROM dbo.DataDictionaryRelationshipCandidate WHERE IsActive = 1;

    -- Fetch fields with generators, sorted by: non-ctx first, then ctx-based
    -- EXCLUDE framework tables (CHANGES, MUTATION, CMF*) as they must be replayed in exact order
    INSERT INTO @Fields (ComponentKey, FieldKey, PhysicalTable, PhysicalColumn, Generator, IsFK, SortOrder)
    SELECT 
        f.ComponentKey,
        f.FieldKey,
        c.PhysicalTable,
        f.PhysicalColumn,
        CASE 
            WHEN f.Notes LIKE '%gen:%' THEN 
                LTRIM(RTRIM(SUBSTRING(f.Notes, CHARINDEX('gen:', f.Notes) + 4, 
                    CASE 
                        WHEN CHARINDEX(CHAR(13), f.Notes, CHARINDEX('gen:', f.Notes)) > 0 
                        THEN CHARINDEX(CHAR(13), f.Notes, CHARINDEX('gen:', f.Notes)) - CHARINDEX('gen:', f.Notes) - 4
                        WHEN CHARINDEX(CHAR(10), f.Notes, CHARINDEX('gen:', f.Notes)) > 0 
                        THEN CHARINDEX(CHAR(10), f.Notes, CHARINDEX('gen:', f.Notes)) - CHARINDEX('gen:', f.Notes) - 4
                        ELSE LEN(f.Notes)
                    END)))
            ELSE NULL
        END,
        CASE WHEN fk.ColumnName IS NOT NULL THEN 1 ELSE 0 END,
        CASE 
            WHEN f.Notes LIKE '%gen:%' AND f.Notes NOT LIKE '%ctx(%' THEN 1  -- Non-ctx generators first
            WHEN f.Notes LIKE '%gen:%' AND f.Notes LIKE '%ctx(%' THEN 2      -- Ctx-based generators second
            ELSE 3                                                             -- No generator last
        END
    FROM dbo.MigrationDomainField f
    INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
    LEFT JOIN @FKFields fk ON fk.TableName = c.PhysicalTable AND fk.ColumnName = f.PhysicalColumn
    WHERE f.ObjectKey = @ObjectKey
      AND c.PhysicalTable NOT IN (N'CHANGES', N'MUTATION')
      AND c.PhysicalTable NOT LIKE N'CMF%'
    ORDER BY SortOrder, f.ComponentKey, f.FieldKey;

    -- Build merged context from all captured tables
    DECLARE @MergedContext NVARCHAR(MAX) = N'{}';
    
    DECLARE @TableName SYSNAME, @RowJson NVARCHAR(MAX);
    DECLARE ctx_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT TableName, RowJson
        FROM dbo.MigrationScenarioRow
        WHERE RunID = @SourceRunID
        ORDER BY TableName, PkValue;
    
    OPEN ctx_cursor;
    FETCH NEXT FROM ctx_cursor INTO @TableName, @RowJson;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @RowJson IS NOT NULL AND ISJSON(@RowJson) = 1
        BEGIN
            -- Merge all fields from this row into context
            DECLARE @Key NVARCHAR(100), @Value NVARCHAR(MAX);
            DECLARE json_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT [key], [value]
                FROM OPENJSON(@RowJson);
            
            OPEN json_cursor;
            FETCH NEXT FROM json_cursor INTO @Key, @Value;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @Value IS NOT NULL
                    SET @MergedContext = JSON_MODIFY(@MergedContext, N'$.' + LOWER(@Key), JSON_VALUE(@RowJson, N'$.' + @Key));
                
                FETCH NEXT FROM json_cursor INTO @Key, @Value;
            END
            
            CLOSE json_cursor;
            DEALLOCATE json_cursor;
        END
        
        FETCH NEXT FROM ctx_cursor INTO @TableName, @RowJson;
    END
    
    CLOSE ctx_cursor;
    DEALLOCATE ctx_cursor;

    -- Process each item by calling ReplayScenarioRun directly
    DECLARE @Results TABLE (ItemIndex INT, ReplayRunID UNIQUEIDENTIFIER);
    DECLARE @ItemIndex INT = 0;

    -- Manage transaction at this level
    BEGIN TRY
        IF @Commit = 1
            BEGIN TRANSACTION;

        WHILE @ItemIndex < @Times
        BEGIN
            -- Start with merged context for this item
            DECLARE @Context NVARCHAR(MAX) = @MergedContext;
            DECLARE @Overrides NVARCHAR(MAX) = N'{}';
            
            -- Evaluate each field in sorted order
            DECLARE @CompKey NVARCHAR(100), @FldKey NVARCHAR(100), @PhysTable SYSNAME, 
                    @PhysCol SYSNAME, @Gen NVARCHAR(MAX), @IsFK BIT;
            
            DECLARE field_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT ComponentKey, FieldKey, PhysicalTable, PhysicalColumn, Generator, IsFK
                FROM @Fields
                ORDER BY SortOrder, ComponentKey, FieldKey;
            
            OPEN field_cursor;
            FETCH NEXT FROM field_cursor INTO @CompKey, @FldKey, @PhysTable, @PhysCol, @Gen, @IsFK;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                DECLARE @GeneratedValue NVARCHAR(MAX) = NULL;
                
                -- Skip FK fields (handled by ReplayScenarioRun)
                IF @IsFK = 0 AND @Gen IS NOT NULL
                BEGIN
                    DECLARE @CurrentItemIndex INT = @ItemIndex + 1;
                    
                    -- Inline evaluation for common generators to avoid stored proc overhead
                    -- ctx(fieldname)
                    IF @Gen LIKE 'ctx(%' AND @Gen NOT LIKE '%,%'
                    BEGIN
                        DECLARE @CtxFieldName NVARCHAR(100) = LTRIM(RTRIM(SUBSTRING(@Gen, 5, LEN(@Gen) - 5)));
                        SET @GeneratedValue = JSON_VALUE(@Context, N'$.' + LOWER(@CtxFieldName));
                    END
                    -- seq()
                    ELSE IF @Gen IN ('seq()', 'seq')
                    BEGIN
                        SET @GeneratedValue = CAST(@CurrentItemIndex AS NVARCHAR(20));
                    END
                    -- literal('value') or literal("value")
                    ELSE IF @Gen LIKE 'literal(%'
                    BEGIN
                        DECLARE @LitValue NVARCHAR(MAX) = LTRIM(RTRIM(SUBSTRING(@Gen, 9, LEN(@Gen) - 9)));
                        IF (@LitValue LIKE '''%''' OR @LitValue LIKE '"%"')
                            SET @GeneratedValue = SUBSTRING(@LitValue, 2, LEN(@LitValue) - 2);
                        ELSE
                            SET @GeneratedValue = @LitValue;
                    END
                    -- concat() with simple ctx() and literals
                    ELSE IF @Gen LIKE 'concat(%' AND @Gen NOT LIKE '%pool(%' AND @Gen NOT LIKE '%random(%'
                    BEGIN
                        -- Simple concat parser for ctx() and string literals
                        DECLARE @ConcatParts NVARCHAR(MAX) = SUBSTRING(@Gen, 8, LEN(@Gen) - 8);
                        DECLARE @Result NVARCHAR(MAX) = '';
                        DECLARE @PartStart INT = 1;
                        DECLARE @PartEnd INT;
                        DECLARE @InQuote BIT = 0;
                        DECLARE @ParenDepth INT = 0;
                        DECLARE @i INT = 1;
                        
                        WHILE @i <= LEN(@ConcatParts)
                        BEGIN
                            DECLARE @Ch NCHAR(1) = SUBSTRING(@ConcatParts, @i, 1);
                            
                            IF @Ch = '''' SET @InQuote = 1 - @InQuote;
                            IF @Ch = '(' AND @InQuote = 0 SET @ParenDepth = @ParenDepth + 1;
                            IF @Ch = ')' AND @InQuote = 0 SET @ParenDepth = @ParenDepth - 1;
                            
                            IF (@Ch = ',' AND @InQuote = 0 AND @ParenDepth = 0) OR @i = LEN(@ConcatParts)
                            BEGIN
                                SET @PartEnd = CASE WHEN @i = LEN(@ConcatParts) THEN @i ELSE @i - 1 END;
                                DECLARE @Part NVARCHAR(MAX) = LTRIM(RTRIM(SUBSTRING(@ConcatParts, @PartStart, @PartEnd - @PartStart + 1)));
                                
                                IF @Part LIKE 'ctx(%'
                                BEGIN
                                    DECLARE @CtxFld NVARCHAR(100) = LTRIM(RTRIM(SUBSTRING(@Part, 5, LEN(@Part) - 5)));
                                    SET @Result = @Result + ISNULL(JSON_VALUE(@Context, N'$.' + LOWER(@CtxFld)), '');
                                END
                                ELSE IF @Part IN ('seq()', 'seq')
                                BEGIN
                                    SET @Result = @Result + CAST(@CurrentItemIndex AS NVARCHAR(20));
                                END
                                ELSE IF @Part LIKE 'literal(%'
                                BEGIN
                                    DECLARE @LitVal NVARCHAR(MAX) = LTRIM(RTRIM(SUBSTRING(@Part, 9, LEN(@Part) - 9)));
                                    IF (@LitVal LIKE '''%''' OR @LitVal LIKE '"%"')
                                        SET @Result = @Result + SUBSTRING(@LitVal, 2, LEN(@LitVal) - 2);
                                    ELSE
                                        SET @Result = @Result + @LitVal;
                                END
                                ELSE IF @Part LIKE '''%'''
                                BEGIN
                                    SET @Result = @Result + SUBSTRING(@Part, 2, LEN(@Part) - 2);
                                END
                                ELSE IF @Part LIKE '"%"'
                                BEGIN
                                    SET @Result = @Result + SUBSTRING(@Part, 2, LEN(@Part) - 2);
                                END
                                
                                SET @PartStart = @i + 1;
                            END
                            
                            SET @i = @i + 1;
                        END
                        
                        SET @GeneratedValue = @Result;
                    END
                    -- For complex generators (pool, random, weighted, etc), use stored procedure
                    ELSE
                    BEGIN
                        EXEC dbo.EvaluateGeneratorExpression
                            @Expression = @Gen,
                            @ItemIndex = @CurrentItemIndex,
                            @ContextJson = @Context,
                            @Result = @GeneratedValue OUTPUT;
                    END
                    
                    IF @GeneratedValue IS NOT NULL
                    BEGIN
                        -- Build overrides JSON for this table.column
                        DECLARE @TablePath NVARCHAR(200) = N'$.' + @PhysTable;
                        DECLARE @ColPath NVARCHAR(300) = @TablePath + N'.' + @PhysCol;
                        
                        -- Ensure table object exists
                        IF JSON_QUERY(@Overrides, @TablePath) IS NULL
                            SET @Overrides = JSON_MODIFY(@Overrides, @TablePath, JSON_QUERY(N'{}'));
                        
                        -- Add column value
                        SET @Overrides = JSON_MODIFY(@Overrides, @ColPath, @GeneratedValue);
                        
                        -- Update context for downstream fields
                        SET @Context = JSON_MODIFY(@Context, N'$.' + LOWER(@FldKey), @GeneratedValue);
                    END
                END
                
                FETCH NEXT FROM field_cursor INTO @CompKey, @FldKey, @PhysTable, @PhysCol, @Gen, @IsFK;
            END
            
            CLOSE field_cursor;
            DEALLOCATE field_cursor;
            
            -- Call ReplayScenarioRun directly with overrides
            DECLARE @Out TABLE (ReplayRunID UNIQUEIDENTIFIER, Iteration INT);
            DELETE FROM @Out;
            
            INSERT INTO @Out(ReplayRunID, Iteration)
            EXEC dbo.ReplayScenarioRun
                @SourceRunID = @SourceRunID,
                @Times = 1,
                @FirstNameBase = NULL,
                @LastNameBase = NULL,
                @OverridesJson = @Overrides,
                @Notes = @Notes,
                @Commit = 0,  -- Don't commit per-iteration
                @ManageTransaction = 0;  -- Don't manage transaction in child proc
            
            DECLARE @ReplayRunID UNIQUEIDENTIFIER = (SELECT TOP 1 ReplayRunID FROM @Out);
            INSERT INTO @Results(ItemIndex, ReplayRunID) VALUES (@ItemIndex, @ReplayRunID);
            
            SET @ItemIndex += 1;
        END

        -- Commit or rollback entire batch
        IF @Commit = 1
            COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @Commit = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    -- Return results to caller
    SELECT ItemIndex, ReplayRunID FROM @Results ORDER BY ItemIndex;
END
GO
