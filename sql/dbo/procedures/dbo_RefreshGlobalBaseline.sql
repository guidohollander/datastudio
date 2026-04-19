SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.RefreshGlobalBaseline
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Clearing existing global baseline...';
    TRUNCATE TABLE dbo.MigrationGlobalBaseline;
    
    DECLARE @TableName SYSNAME;
    DECLARE @PkColumn SYSNAME;
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @RowCount INT;
    
    DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT t.TableName, c.ColumnName
    FROM dbo.DataDictionaryTable t
    INNER JOIN dbo.DataDictionaryColumn c ON c.TableObjectId = t.TableObjectId
    WHERE c.IsPrimaryKey = 1
      AND NOT EXISTS (
        SELECT 1 
        FROM dbo.MigrationTableExclusions e
        WHERE t.TableName LIKE e.TablePattern
    );
    
    OPEN table_cursor;
    FETCH NEXT FROM table_cursor INTO @TableName, @PkColumn;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Check if table has any rows
        SET @RowCount = 0;
        SET @SQL = N'SELECT @RowCount = COUNT(*) FROM ' + QUOTENAME(@TableName) + ' WITH (NOLOCK);';
        
        BEGIN TRY
            EXEC sp_executesql @SQL, N'@RowCount INT OUTPUT', @RowCount OUTPUT;
        END TRY
        BEGIN CATCH
            SET @RowCount = 0;
        END CATCH
        
        -- Snapshot all tables with data (no size limit for baseline)
        IF @RowCount > 0
        BEGIN
            PRINT 'Snapshotting ' + @TableName + ' (' + CAST(@RowCount AS VARCHAR(10)) + ' rows)...';
            
            SET @SQL = N'
                INSERT INTO dbo.MigrationGlobalBaseline (TableName, PkColumn, PkValue, RowHash, RowJson)
                SELECT 
                    @TableName,
                    @PkColumn,
                    CONVERT(NVARCHAR(450), ' + QUOTENAME(@PkColumn) + '),
                    HASHBYTES(''SHA2_256'', (SELECT * FROM ' + QUOTENAME(@TableName) + ' t WHERE t.' + QUOTENAME(@PkColumn) + ' = src.' + QUOTENAME(@PkColumn) + ' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)),
                    (SELECT * FROM ' + QUOTENAME(@TableName) + ' t WHERE t.' + QUOTENAME(@PkColumn) + ' = src.' + QUOTENAME(@PkColumn) + ' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
                FROM ' + QUOTENAME(@TableName) + ' src WITH (NOLOCK);';
            
            BEGIN TRY
                EXEC sp_executesql @SQL, 
                    N'@TableName SYSNAME, @PkColumn SYSNAME', 
                    @TableName, @PkColumn;
            END TRY
            BEGIN CATCH
                PRINT 'Error snapshotting table ' + @TableName + ': ' + ERROR_MESSAGE();
            END CATCH
        END
        
        FETCH NEXT FROM table_cursor INTO @TableName, @PkColumn;
    END
    
    CLOSE table_cursor;
    DEALLOCATE table_cursor;
    
    PRINT 'Global baseline refresh complete.';
    SELECT COUNT(*) as TotalBaselineRows, COUNT(DISTINCT TableName) as TotalTables
    FROM dbo.MigrationGlobalBaseline;
END
GO
