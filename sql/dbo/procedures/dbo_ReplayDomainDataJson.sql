SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.ReplayDomainDataJson
    @SourceRunID UNIQUEIDENTIFIER,
    @ContractJson NVARCHAR(MAX),
    @DataJson NVARCHAR(MAX),
    @Notes NVARCHAR(2000) = NULL,
    @Commit BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.EnsureDomainContractDefaults;

    IF @ContractJson IS NULL OR ISJSON(@ContractJson) <> 1
        THROW 50000, N'ContractJson must be valid JSON.', 1;

    IF @DataJson IS NULL OR ISJSON(@DataJson) <> 1
        THROW 50000, N'DataJson must be valid JSON.', 1;

    DECLARE @ObjectKey NVARCHAR(100) = JSON_VALUE(@ContractJson, N'$.object.objectKey');
    IF @ObjectKey IS NULL
        THROW 50000, N'ContractJson is missing object.objectKey.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainObject WHERE ObjectKey = @ObjectKey)
        THROW 50000, N'Unknown objectKey in contract.', 1;

    DECLARE @Items NVARCHAR(MAX) = JSON_QUERY(@DataJson, N'$.items');
    IF @Items IS NULL
        THROW 50000, N'DataJson is missing items.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationScenarioRow WHERE RunID = @SourceRunID)
        THROW 50000, N'No captured scenario rows found for SourceRunID.', 1;

    DECLARE @Results TABLE (ItemIndex INT NOT NULL, ReplayRunID UNIQUEIDENTIFIER NOT NULL);
    DECLARE @Out TABLE (ReplayRunID UNIQUEIDENTIFIER, Iteration INT);

    DECLARE @i INT = 0;
    DECLARE @n INT = (SELECT COUNT(1) FROM OPENJSON(@Items));

    -- Manage transaction at this level instead of in ReplayScenarioRun
    BEGIN TRY
        BEGIN TRANSACTION;

    WHILE @i < @n
    BEGIN
        DECLARE @Item NVARCHAR(MAX) = JSON_QUERY(@Items, N'$[' + CONVERT(NVARCHAR(20), @i) + N']');
        IF @Item IS NULL
            THROW 50000, N'Invalid item entry.', 1;

        DECLARE @Overrides NVARCHAR(MAX) = N'{}';

        DECLARE @CompKey NVARCHAR(100);
        DECLARE @CompJson NVARCHAR(MAX);

        DECLARE comp_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT c.ComponentKey
            FROM dbo.MigrationDomainComponent c
            WHERE c.ObjectKey = @ObjectKey
            ORDER BY c.SortOrder, c.ComponentKey;

        OPEN comp_cursor;
        FETCH NEXT FROM comp_cursor INTO @CompKey;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @CompJson = JSON_QUERY(@Item, N'$.' + @CompKey);

            IF @CompJson IS NOT NULL
            BEGIN
                DECLARE @PhysicalTable SYSNAME;
                SELECT @PhysicalTable = c.PhysicalTable
                FROM dbo.MigrationDomainComponent c
                WHERE c.ObjectKey = @ObjectKey AND c.ComponentKey = @CompKey;

                IF @PhysicalTable IS NULL
                    THROW 50000, N'Component mapping missing.', 1;

                IF LEFT(LTRIM(@CompJson), 1) = N'['
                BEGIN
                    DECLARE @FirstRow NVARCHAR(MAX) = JSON_QUERY(@CompJson, N'$[0]');
                    IF @FirstRow IS NOT NULL
                        SET @CompJson = @FirstRow;
                END

                DECLARE @TableObj NVARCHAR(MAX) = N'{}';
                DECLARE @FieldKey NVARCHAR(100);
                DECLARE @PhysicalColumn SYSNAME;
                DECLARE @Val NVARCHAR(MAX);

                DECLARE field_cursor CURSOR LOCAL FAST_FORWARD FOR
                    SELECT f.FieldKey, f.PhysicalColumn
                    FROM dbo.MigrationDomainField f
                    WHERE f.ObjectKey = @ObjectKey AND f.ComponentKey = @CompKey
                    ORDER BY f.FieldKey;

                OPEN field_cursor;
                FETCH NEXT FROM field_cursor INTO @FieldKey, @PhysicalColumn;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SET @Val = JSON_QUERY(@CompJson, N'$.' + @FieldKey);
                    IF @Val IS NULL
                        SET @Val = JSON_VALUE(@CompJson, N'$.' + @FieldKey);

                    IF @Val IS NOT NULL
                    BEGIN
                        IF LEFT(LTRIM(@Val), 1) IN (N'{', N'[')
                            SET @TableObj = JSON_MODIFY(@TableObj, N'$.' + @PhysicalColumn, JSON_QUERY(@CompJson, N'$.' + @FieldKey));
                        ELSE
                            SET @TableObj = JSON_MODIFY(@TableObj, N'$.' + @PhysicalColumn, JSON_VALUE(@CompJson, N'$.' + @FieldKey));
                    END

                    FETCH NEXT FROM field_cursor INTO @FieldKey, @PhysicalColumn;
                END

                CLOSE field_cursor;
                DEALLOCATE field_cursor;

                SET @Overrides = JSON_MODIFY(@Overrides, N'$.' + @PhysicalTable, JSON_QUERY(@TableObj));
            END

            FETCH NEXT FROM comp_cursor INTO @CompKey;
        END

        CLOSE comp_cursor;
        DEALLOCATE comp_cursor;

        DELETE FROM @Out;

        INSERT INTO @Out(ReplayRunID, Iteration)
        EXEC dbo.ReplayScenarioRun
            @SourceRunID = @SourceRunID,
            @Times = 1,
            @FirstNameBase = NULL,
            @LastNameBase = NULL,
            @OverridesJson = @Overrides,
            @Notes = @Notes,
            @Commit = 0,  -- Don't commit per-iteration, commit at end
            @ManageTransaction = 0;  -- Don't manage transaction in child proc

        DECLARE @ReplayRunID UNIQUEIDENTIFIER = (SELECT TOP 1 ReplayRunID FROM @Out);
        INSERT INTO @Results(ItemIndex, ReplayRunID) VALUES (@i, @ReplayRunID);

        SET @i += 1;
    END

        -- Commit or rollback entire batch
        IF @Commit = 1
            COMMIT TRANSACTION;
        ELSE
            ROLLBACK TRANSACTION;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT ItemIndex, ReplayRunID FROM @Results ORDER BY ItemIndex;
END
GO
