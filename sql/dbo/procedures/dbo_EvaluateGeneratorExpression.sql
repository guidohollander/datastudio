SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.EvaluateGeneratorExpression
    @Expression NVARCHAR(MAX),
    @ItemIndex INT,
    @ContextJson NVARCHAR(MAX) = NULL,
    @Result NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ExprLower NVARCHAR(MAX) = LOWER(LTRIM(RTRIM(@Expression)));
    DECLARE @FuncName NVARCHAR(100);
    DECLARE @Args NVARCHAR(MAX);
    DECLARE @RandomSeed INT = ABS(CHECKSUM(NEWID()));

    -- If empty, return NULL
    IF @ExprLower IS NULL OR @ExprLower = ''
    BEGIN
        SET @Result = NULL;
        RETURN;
    END

    -- Extract function name and arguments
    IF @ExprLower LIKE '%(%'
    BEGIN
        SET @FuncName = SUBSTRING(@ExprLower, 1, CHARINDEX('(', @ExprLower) - 1);
        SET @Args = SUBSTRING(@Expression, CHARINDEX('(', @Expression) + 1, LEN(@Expression) - CHARINDEX('(', @Expression) - 1);
    END
    ELSE
    BEGIN
        -- No function, treat as literal
        SET @Result = @Expression;
        RETURN;
    END

    -- seq() - Sequential numbers
    IF @FuncName = 'seq'
    BEGIN
        SET @Result = CONVERT(NVARCHAR(MAX), @ItemIndex);
        RETURN;
    END

    -- unique(tableName, columnName) - Generate unique values starting from max + 1
    IF @FuncName = 'unique'
    BEGIN
        DECLARE @CommaPos2 INT = CHARINDEX(',', @Args);
        IF @CommaPos2 > 0
        BEGIN
            DECLARE @TableName NVARCHAR(200) = LTRIM(RTRIM(SUBSTRING(@Args, 1, @CommaPos2 - 1)));
            DECLARE @ColumnName NVARCHAR(200) = LTRIM(RTRIM(SUBSTRING(@Args, @CommaPos2 + 1, LEN(@Args))));
            
            -- Remove quotes if present
            SET @TableName = REPLACE(REPLACE(@TableName, '''', ''), '"', '');
            SET @ColumnName = REPLACE(REPLACE(@ColumnName, '''', ''), '"', '');
            
            -- Get max value from table
            DECLARE @MaxValue INT;
            DECLARE @SQL NVARCHAR(MAX) = N'SELECT @MaxOut = ISNULL(MAX(' + QUOTENAME(@ColumnName) + '), 0) FROM ' + QUOTENAME(@TableName);
            
            EXEC sp_executesql @SQL, N'@MaxOut INT OUTPUT', @MaxOut = @MaxValue OUTPUT;
            
            SET @Result = CONVERT(NVARCHAR(MAX), @MaxValue + @ItemIndex);
        END
        
        RETURN;
    END

    -- newguid() - Generate unique GUID
    IF @FuncName = 'newguid'
    BEGIN
        SET @Result = CONVERT(NVARCHAR(MAX), NEWID());
        RETURN;
    END

    -- ctx(variableName) - Retrieve value from context JSON (case-insensitive)
    IF @FuncName = 'ctx'
    BEGIN
        DECLARE @VarName NVARCHAR(100) = REPLACE(REPLACE(@Args, '''', ''), '"', '');
        
        IF @ContextJson IS NOT NULL
        BEGIN
            -- Try lowercase first
            SET @Result = JSON_VALUE(@ContextJson, '$.' + LOWER(@VarName));
            
            -- If not found, try uppercase
            IF @Result IS NULL
                SET @Result = JSON_VALUE(@ContextJson, '$.' + UPPER(@VarName));
            
            -- If still not found, try original case
            IF @Result IS NULL
                SET @Result = JSON_VALUE(@ContextJson, '$.' + @VarName);
        END
        
        RETURN;
    END

    -- lookup(refTableName) - Pick random valid CODE from SC_PERSONREGISTRATION_CONVERSION_REF_* table
    IF @FuncName = 'lookup'
    BEGIN
        DECLARE @RefTable NVARCHAR(200) = REPLACE(REPLACE(@Args, '''', ''), '"', '');
        
        -- Build full synonym name
        DECLARE @SynonymName NVARCHAR(300) = 'SC_PERSONREGISTRATION_CONVERSION_REF_' + UPPER(@RefTable);
        
        -- Check if synonym exists
        IF EXISTS (SELECT 1 FROM sys.synonyms WHERE name = @SynonymName)
        BEGIN
            -- Query random CODE (numeric value) from the reference table using dynamic SQL
            DECLARE @LookupSql NVARCHAR(MAX);
            SET @LookupSql = 
                N'SELECT TOP 1 @ResultOut = CONVERT(NVARCHAR(MAX), CODE) ' +
                N'FROM ' + QUOTENAME(@SynonymName) + N' ' +
                N'WHERE CODE IS NOT NULL ' +
                N'ORDER BY NEWID();';
            
            EXEC sp_executesql @LookupSql, N'@ResultOut NVARCHAR(MAX) OUTPUT', @ResultOut = @Result OUTPUT;
        END
        ELSE
        BEGIN
            -- Fallback: return NULL if table doesn't exist
            SET @Result = NULL;
        END
        
        RETURN;
    END

    -- literal('text') - Fixed value
    IF @FuncName = 'literal'
    BEGIN
        SET @Result = REPLACE(REPLACE(@Args, '''', ''), '"', '');
        RETURN;
    END

    -- pick(A|B|C) - Rotate through values
    IF @FuncName = 'pick'
    BEGIN
        DECLARE @PickValues TABLE (RowNum INT IDENTITY(1,1), Val NVARCHAR(500));
        DECLARE @PickValue NVARCHAR(500);
        DECLARE @Delimiter NVARCHAR(1) = '|';
        
        -- Split by |
        DECLARE @Pos INT = 1;
        DECLARE @NextPos INT;
        DECLARE @ValuePart NVARCHAR(500);
        
        WHILE @Pos <= LEN(@Args)
        BEGIN
            SET @NextPos = CHARINDEX(@Delimiter, @Args, @Pos);
            IF @NextPos = 0 SET @NextPos = LEN(@Args) + 1;
            
            SET @ValuePart = LTRIM(RTRIM(SUBSTRING(@Args, @Pos, @NextPos - @Pos)));
            INSERT INTO @PickValues (Val) VALUES (@ValuePart);
            
            SET @Pos = @NextPos + 1;
        END
        
        DECLARE @PickCount INT;
        SELECT @PickCount = COUNT(*) FROM @PickValues;
        
        IF @PickCount > 0
        BEGIN
            DECLARE @PickIndex INT = ((@ItemIndex - 1) % @PickCount) + 1;
            SELECT @Result = Val FROM @PickValues WHERE RowNum = @PickIndex;
        END
        
        RETURN;
    END

    -- pool(poolName) - Random from reference data pool with weighting
    IF @FuncName = 'pool'
    BEGIN
        DECLARE @PoolName NVARCHAR(100) = REPLACE(REPLACE(@Args, '''', ''), '"', '');
        
        -- Get weighted random value
        SELECT TOP 1 @Result = Value
        FROM dbo.ReferenceDataPool
        WHERE PoolName = @PoolName
        ORDER BY (ABS(CHECKSUM(NEWID())) % (Weight * 100));
        
        RETURN;
    END

    -- weighted(Male:51|Female:49) - Weighted random selection
    IF @FuncName = 'weighted'
    BEGIN
        DECLARE @WeightedValues TABLE (Val NVARCHAR(500), Weight INT);
        DECLARE @TotalWeight INT = 0;
        
        -- Parse weighted values
        SET @Pos = 1;
        WHILE @Pos <= LEN(@Args)
        BEGIN
            SET @NextPos = CHARINDEX('|', @Args, @Pos);
            IF @NextPos = 0 SET @NextPos = LEN(@Args) + 1;
            
            SET @ValuePart = LTRIM(RTRIM(SUBSTRING(@Args, @Pos, @NextPos - @Pos)));
            
            DECLARE @ColonPos INT = CHARINDEX(':', @ValuePart);
            IF @ColonPos > 0
            BEGIN
                DECLARE @Val NVARCHAR(500) = LTRIM(RTRIM(SUBSTRING(@ValuePart, 1, @ColonPos - 1)));
                DECLARE @Weight INT = CONVERT(INT, LTRIM(RTRIM(SUBSTRING(@ValuePart, @ColonPos + 1, LEN(@ValuePart)))));
                
                INSERT INTO @WeightedValues (Val, Weight) VALUES (@Val, @Weight);
                SET @TotalWeight += @Weight;
            END
            
            SET @Pos = @NextPos + 1;
        END
        
        -- Select based on weight
        DECLARE @RandomValue INT = ABS(CHECKSUM(NEWID())) % @TotalWeight;
        DECLARE @CumulativeWeight INT = 0;
        
        DECLARE weight_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT Val, Weight FROM @WeightedValues ORDER BY Val;
        
        OPEN weight_cursor;
        FETCH NEXT FROM weight_cursor INTO @Val, @Weight;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @CumulativeWeight += @Weight;
            IF @RandomValue < @CumulativeWeight
            BEGIN
                SET @Result = @Val;
                BREAK;
            END
            FETCH NEXT FROM weight_cursor INTO @Val, @Weight;
        END
        
        CLOSE weight_cursor;
        DEALLOCATE weight_cursor;
        
        RETURN;
    END

    -- random(min, max) - Random integer
    IF @FuncName = 'random'
    BEGIN
        DECLARE @CommaPos INT = CHARINDEX(',', @Args);
        IF @CommaPos > 0
        BEGIN
            DECLARE @Min INT = CONVERT(INT, LTRIM(RTRIM(SUBSTRING(@Args, 1, @CommaPos - 1))));
            DECLARE @Max INT = CONVERT(INT, LTRIM(RTRIM(SUBSTRING(@Args, @CommaPos + 1, LEN(@Args)))));
            
            SET @Result = CONVERT(NVARCHAR(MAX), @Min + (ABS(CHECKSUM(NEWID())) % (@Max - @Min + 1)));
        END
        
        RETURN;
    END

    -- dateRange(2020-01-01, 2025-12-31) - Random date in range
    IF @FuncName = 'daterange'
    BEGIN
        SET @CommaPos = CHARINDEX(',', @Args);
        IF @CommaPos > 0
        BEGIN
            DECLARE @StartDate DATE = CONVERT(DATE, LTRIM(RTRIM(SUBSTRING(@Args, 1, @CommaPos - 1))));
            DECLARE @EndDate DATE = CONVERT(DATE, LTRIM(RTRIM(SUBSTRING(@Args, @CommaPos + 1, LEN(@Args)))));
            
            DECLARE @DaysDiff INT = DATEDIFF(DAY, @StartDate, @EndDate);
            DECLARE @RandomDays INT = ABS(CHECKSUM(NEWID())) % (@DaysDiff + 1);
            
            SET @Result = CONVERT(NVARCHAR(MAX), DATEADD(DAY, @RandomDays, @StartDate), 23);
        END
        
        RETURN;
    END

    -- ageRange(18, 65) - Date of birth based on age range
    IF @FuncName = 'agerange'
    BEGIN
        SET @CommaPos = CHARINDEX(',', @Args);
        IF @CommaPos > 0
        BEGIN
            DECLARE @MinAge INT = CONVERT(INT, LTRIM(RTRIM(SUBSTRING(@Args, 1, @CommaPos - 1))));
            DECLARE @MaxAge INT = CONVERT(INT, LTRIM(RTRIM(SUBSTRING(@Args, @CommaPos + 1, LEN(@Args)))));
            
            DECLARE @RandomAge INT = @MinAge + (ABS(CHECKSUM(NEWID())) % (@MaxAge - @MinAge + 1));
            DECLARE @BirthDate DATE = DATEADD(YEAR, -@RandomAge, GETDATE());
            
            -- Add random days within the year
            DECLARE @RandomDaysInYear INT = ABS(CHECKSUM(NEWID())) % 365;
            SET @BirthDate = DATEADD(DAY, -@RandomDaysInYear, @BirthDate);
            
            SET @Result = CONVERT(NVARCHAR(MAX), @BirthDate, 23);
        END
        
        RETURN;
    END

    -- concat(...) - Concatenate multiple values/expressions
    IF @FuncName = 'concat'
    BEGIN
        SET @Result = '';
        SET @Pos = 1;
        
        WHILE @Pos <= LEN(@Args)
        BEGIN
            -- Find next comma (but not inside nested function calls)
            DECLARE @ParenDepth INT = 0;
            DECLARE @InQuote BIT = 0;
            SET @NextPos = @Pos;
            
            WHILE @NextPos <= LEN(@Args)
            BEGIN
                DECLARE @Char NCHAR(1) = SUBSTRING(@Args, @NextPos, 1);
                
                IF @Char = '''' SET @InQuote = 1 - @InQuote;
                IF @InQuote = 0
                BEGIN
                    IF @Char = '(' SET @ParenDepth += 1;
                    IF @Char = ')' SET @ParenDepth -= 1;
                    IF @Char = ',' AND @ParenDepth = 0 BREAK;
                END
                
                SET @NextPos += 1;
            END
            
            IF @NextPos > LEN(@Args) SET @NextPos = LEN(@Args) + 1;
            
            SET @ValuePart = LTRIM(RTRIM(SUBSTRING(@Args, @Pos, @NextPos - @Pos)));
            
            -- Check if it's a nested expression or literal
            IF @ValuePart LIKE '%(%'
            BEGIN
                DECLARE @NestedResult NVARCHAR(MAX);
                EXEC dbo.EvaluateGeneratorExpression @ValuePart, @ItemIndex, @ContextJson, @NestedResult OUTPUT;
                SET @Result += ISNULL(@NestedResult, '');
            END
            ELSE
            BEGIN
                -- Remove quotes if literal string
                SET @ValuePart = REPLACE(REPLACE(@ValuePart, '''', ''), '"', '');
                SET @Result += @ValuePart;
            END
            
            SET @Pos = @NextPos + 1;
        END
        
        RETURN;
    END

    -- email(firstName, surname, domain) - Generate email
    IF @FuncName = 'email'
    BEGIN
        -- Parse arguments
        DECLARE @EmailParts TABLE (PartNum INT IDENTITY(1,1), Part NVARCHAR(500));
        SET @Pos = 1;
        
        WHILE @Pos <= LEN(@Args)
        BEGIN
            SET @ParenDepth = 0;
            SET @InQuote = 0;
            SET @NextPos = @Pos;
            
            WHILE @NextPos <= LEN(@Args)
            BEGIN
                SET @Char = SUBSTRING(@Args, @NextPos, 1);
                IF @Char = '''' SET @InQuote = 1 - @InQuote;
                IF @InQuote = 0
                BEGIN
                    IF @Char = '(' SET @ParenDepth += 1;
                    IF @Char = ')' SET @ParenDepth -= 1;
                    IF @Char = ',' AND @ParenDepth = 0 BREAK;
                END
                SET @NextPos += 1;
            END
            
            IF @NextPos > LEN(@Args) SET @NextPos = LEN(@Args) + 1;
            SET @ValuePart = LTRIM(RTRIM(SUBSTRING(@Args, @Pos, @NextPos - @Pos)));
            INSERT INTO @EmailParts (Part) VALUES (@ValuePart);
            SET @Pos = @NextPos + 1;
        END
        
        -- Evaluate each part
        DECLARE @FirstName NVARCHAR(500), @Surname NVARCHAR(500), @Domain NVARCHAR(500);
        
        SELECT @FirstName = Part FROM @EmailParts WHERE PartNum = 1;
        SELECT @Surname = Part FROM @EmailParts WHERE PartNum = 2;
        SELECT @Domain = Part FROM @EmailParts WHERE PartNum = 3;
        
        -- Evaluate expressions
        IF @FirstName LIKE '%(%'
            EXEC dbo.EvaluateGeneratorExpression @FirstName, @ItemIndex, @ContextJson, @FirstName OUTPUT;
        ELSE
            SET @FirstName = REPLACE(REPLACE(@FirstName, '''', ''), '"', '');
            
        IF @Surname LIKE '%(%'
            EXEC dbo.EvaluateGeneratorExpression @Surname, @ItemIndex, @ContextJson, @Surname OUTPUT;
        ELSE
            SET @Surname = REPLACE(REPLACE(@Surname, '''', ''), '"', '');
            
        IF @Domain LIKE '%(%'
            EXEC dbo.EvaluateGeneratorExpression @Domain, @ItemIndex, @ContextJson, @Domain OUTPUT;
        ELSE
            SET @Domain = REPLACE(REPLACE(@Domain, '''', ''), '"', '');
        
        -- Build email
        SET @Result = LOWER(REPLACE(@FirstName, ' ', '.') + '.' + REPLACE(@Surname, ' ', '.') + '@' + @Domain);
        RETURN;
    END

    -- xmltemplate(fieldName) - Use XML from context as template, substitute field values
    IF @FuncName = 'xmltemplate'
    BEGIN
        DECLARE @TemplateFieldName NVARCHAR(100) = REPLACE(REPLACE(@Args, '''', ''), '"', '');
        DECLARE @XmlTemplate NVARCHAR(MAX);
        
        -- Get the XML template from context
        IF @ContextJson IS NOT NULL
        BEGIN
            SET @XmlTemplate = JSON_VALUE(@ContextJson, '$.' + LOWER(@TemplateFieldName));
            IF @XmlTemplate IS NULL
                SET @XmlTemplate = JSON_VALUE(@ContextJson, '$.' + UPPER(@TemplateFieldName));
            IF @XmlTemplate IS NULL
                SET @XmlTemplate = JSON_VALUE(@ContextJson, '$.' + @TemplateFieldName);
        END
        
        IF @XmlTemplate IS NOT NULL AND @ContextJson IS NOT NULL
        BEGIN
            -- Substitute common field values in CDATA sections
            -- Pattern: <FieldName><![CDATA[value]]></FieldName>
            DECLARE @FieldsToReplace TABLE (FieldName NVARCHAR(100));
            INSERT INTO @FieldsToReplace VALUES 
                ('FirstNames'), ('Surname'), ('BirthName'), ('DateOfBirth'), ('Gender'),
                ('IdentificationNumber'), ('IdentificationType'), ('Resident'),
                ('IndividualRecordId'), ('PersonIdentificationRecordId'), 
                ('HomeAddressRecordId'), ('ContactRecordId'), ('PersonGUID');
            
            DECLARE @FieldToReplace NVARCHAR(100);
            DECLARE @FieldValue NVARCHAR(MAX);
            DECLARE @Pattern NVARCHAR(500);
            DECLARE @Replacement NVARCHAR(MAX);
            
            DECLARE field_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT FieldName FROM @FieldsToReplace;
            
            OPEN field_cursor;
            FETCH NEXT FROM field_cursor INTO @FieldToReplace;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Get value from context (case-insensitive)
                SET @FieldValue = JSON_VALUE(@ContextJson, '$.' + LOWER(@FieldToReplace));
                IF @FieldValue IS NULL
                    SET @FieldValue = JSON_VALUE(@ContextJson, '$.' + UPPER(@FieldToReplace));
                
                IF @FieldValue IS NOT NULL
                BEGIN
                    -- Replace pattern: <FieldName><![CDATA[...]]></FieldName>
                    -- with: <FieldName><![CDATA[newValue]]></FieldName>
                    SET @Pattern = '<' + @FieldToReplace + '><![CDATA[%]]></' + @FieldToReplace + '>';
                    SET @Replacement = '<' + @FieldToReplace + '><![CDATA[' + @FieldValue + ']]></' + @FieldToReplace + '>';
                    
                    -- Find and replace using PATINDEX
                    DECLARE @StartPos INT = PATINDEX('%' + @Pattern + '%', @XmlTemplate);
                    IF @StartPos > 0
                    BEGIN
                        DECLARE @EndTag NVARCHAR(100) = '</' + @FieldToReplace + '>';
                        DECLARE @EndPos INT = CHARINDEX(@EndTag, @XmlTemplate, @StartPos) + LEN(@EndTag);
                        DECLARE @OldValue NVARCHAR(MAX) = SUBSTRING(@XmlTemplate, @StartPos, @EndPos - @StartPos);
                        
                        SET @XmlTemplate = REPLACE(@XmlTemplate, @OldValue, @Replacement);
                    END
                END
                
                FETCH NEXT FROM field_cursor INTO @FieldToReplace;
            END
            
            CLOSE field_cursor;
            DEALLOCATE field_cursor;
            
            SET @Result = @XmlTemplate;
        END
        ELSE
        BEGIN
            SET @Result = NULL;
        END
        
        RETURN;
    END

    -- Default: return as literal
    SET @Result = @Expression;
END
GO
