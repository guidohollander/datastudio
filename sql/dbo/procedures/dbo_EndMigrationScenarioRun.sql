SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.EndMigrationScenarioRun
    @RunID UNIQUEIDENTIFIER,
    @Notes NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationScenarioRun WHERE RunID = @RunID)
        THROW 50000, N'Unknown RunID.', 1;

    EXEC dbo.GetNewRowsSinceSnapshot;

    DELETE FROM dbo.MigrationScenarioNewRows
    WHERE RunID = @RunID;

    INSERT INTO dbo.MigrationScenarioNewRows (RunID, TableName, NewIdentityValue, FoundAt)
    SELECT @RunID, TableName, NewIdentityValue, FoundAt
    FROM dbo.NewRowsSinceSnapshotResult;

    -- Capture changed rows by comparing current state with global baseline
    -- This approach is much faster as we don't create per-run snapshots
    DECLARE @TableName SYSNAME;
    DECLARE @PkColumn SYSNAME;
    DECLARE @SQL NVARCHAR(MAX);
    
    DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT TableName, PkColumn
    FROM dbo.MigrationGlobalBaseline
    ORDER BY TableName;
    
    OPEN table_cursor;
    FETCH NEXT FROM table_cursor INTO @TableName, @PkColumn;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Capture INSERT operations (new rows not in baseline)
        SET @SQL = N'
            INSERT INTO dbo.MigrationScenarioRow (RunID, TableName, PkColumn, PkValue, RowJson, ChangeType)
            SELECT 
                @RunID,
                @TableName,
                @PkColumn,
                ' + QUOTENAME(@PkColumn) + ',
                (SELECT * FROM ' + QUOTENAME(@TableName) + ' t WHERE t.' + QUOTENAME(@PkColumn) + ' = src.' + QUOTENAME(@PkColumn) + ' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
                ''INSERT''
            FROM ' + QUOTENAME(@TableName) + ' src WITH (NOLOCK)
            WHERE NOT EXISTS (
                SELECT 1 FROM dbo.MigrationGlobalBaseline baseline
                WHERE baseline.TableName = @TableName
                  AND baseline.PkValue = CONVERT(NVARCHAR(450), src.' + QUOTENAME(@PkColumn) + ')
            );';
        
        BEGIN TRY
            EXEC sp_executesql @SQL, 
                N'@RunID UNIQUEIDENTIFIER, @TableName SYSNAME, @PkColumn SYSNAME', 
                @RunID, @TableName, @PkColumn;
        END TRY
        BEGIN CATCH
            PRINT 'Error capturing INSERTs for table ' + @TableName + ': ' + ERROR_MESSAGE();
        END CATCH
        
        -- Capture UPDATE operations (rows in baseline with different hash)
        SET @SQL = N'
            INSERT INTO dbo.MigrationScenarioRow (RunID, TableName, PkColumn, PkValue, RowJson, ChangeType)
            SELECT 
                @RunID,
                @TableName,
                @PkColumn,
                src.' + QUOTENAME(@PkColumn) + ',
                (SELECT * FROM ' + QUOTENAME(@TableName) + ' t WHERE t.' + QUOTENAME(@PkColumn) + ' = src.' + QUOTENAME(@PkColumn) + ' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
                ''UPDATE''
            FROM ' + QUOTENAME(@TableName) + ' src WITH (NOLOCK)
            INNER JOIN dbo.MigrationGlobalBaseline baseline
                ON baseline.TableName = @TableName
                AND baseline.PkValue = CONVERT(NVARCHAR(450), src.' + QUOTENAME(@PkColumn) + ')
            WHERE baseline.RowHash != HASHBYTES(''SHA2_256'', (SELECT * FROM ' + QUOTENAME(@TableName) + ' t WHERE t.' + QUOTENAME(@PkColumn) + ' = src.' + QUOTENAME(@PkColumn) + ' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER));';
        
        BEGIN TRY
            EXEC sp_executesql @SQL, 
                N'@RunID UNIQUEIDENTIFIER, @TableName SYSNAME, @PkColumn SYSNAME', 
                @RunID, @TableName, @PkColumn;
        END TRY
        BEGIN CATCH
            PRINT 'Error capturing UPDATEs for table ' + @TableName + ': ' + ERROR_MESSAGE();
        END CATCH
        
        -- Capture DELETE operations (rows in baseline but not in current table)
        SET @SQL = N'
            INSERT INTO dbo.MigrationScenarioRow (RunID, TableName, PkColumn, PkValue, RowJson, ChangeType)
            SELECT 
                @RunID,
                @TableName,
                @PkColumn,
                baseline.PkValue,
                baseline.RowJson,
                ''DELETE''
            FROM dbo.MigrationGlobalBaseline baseline
            WHERE baseline.TableName = @TableName
              AND NOT EXISTS (
                SELECT 1 FROM ' + QUOTENAME(@TableName) + ' src
                WHERE CONVERT(NVARCHAR(450), src.' + QUOTENAME(@PkColumn) + ') = baseline.PkValue
              );';
        
        BEGIN TRY
            EXEC sp_executesql @SQL, 
                N'@RunID UNIQUEIDENTIFIER, @TableName SYSNAME, @PkColumn SYSNAME', 
                @RunID, @TableName, @PkColumn;
        END TRY
        BEGIN CATCH
            PRINT 'Error capturing DELETEs for table ' + @TableName + ': ' + ERROR_MESSAGE();
        END CATCH
        
        FETCH NEXT FROM table_cursor INTO @TableName, @PkColumn;
    END
    
    CLOSE table_cursor;
    DEALLOCATE table_cursor;

    UPDATE dbo.MigrationScenarioRun
    SET EndedAt = SYSUTCDATETIME(),
        Notes = COALESCE(@Notes, Notes)
    WHERE RunID = @RunID;

    SELECT RunID, TableName, NewIdentityValue, FoundAt
    FROM dbo.MigrationScenarioNewRows
    WHERE RunID = @RunID
    ORDER BY FoundAt, TableName, NewIdentityValue;
END
GO
