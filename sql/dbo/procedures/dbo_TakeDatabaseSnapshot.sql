-- =============================================
-- STEP 3: TAKE SNAPSHOT (IDENTITY PK OR HASH)
-- =============================================

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.TakeDatabaseSnapshot
    @SnapshotID UNIQUEIDENTIFIER = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @SnapshotID IS NULL SET @SnapshotID = NEWID();

    -- Keep only 2 latest snapshots
    DELETE FROM dbo.Snapshot_Hashes
    WHERE SnapshotID IN (
        SELECT SnapshotID
        FROM (
            SELECT SnapshotID, ROW_NUMBER() OVER (ORDER BY MAX(SnapshotTime) DESC) AS rn
            FROM dbo.Snapshot_Hashes
            GROUP BY SnapshotID
        ) ranked
        WHERE rn > 2
    );

    DECLARE @schema SYSNAME, @table SYSNAME, @fullTable SYSNAME;
    DECLARE @sql NVARCHAR(MAX), @pkCol SYSNAME;

    DECLARE cur CURSOR FOR
    SELECT TABLE_SCHEMA, TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_TYPE = 'BASE TABLE'
      AND TABLE_SCHEMA = 'dbo'
      AND TABLE_NAME NOT IN ('Snapshot_Hashes', 'MigrationLog');

    OPEN cur;
    FETCH NEXT FROM cur INTO @schema, @table;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @fullTable = QUOTENAME(@schema) + '.' + QUOTENAME(@table);

        SELECT TOP 1 @pkCol = COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = @schema AND TABLE_NAME = @table
          AND COLUMNPROPERTY(OBJECT_ID(@schema + '.' + @table), COLUMN_NAME, 'IsIdentity') = 1;

        IF @pkCol IS NOT NULL
        BEGIN
            -- For tables with identity PKs, just store the max PK value
            SET @sql = '
            INSERT INTO dbo.Snapshot_Hashes (SnapshotID, TableName, PrimaryKey, RowHash, SnapshotTime)
            SELECT
                @SnapshotID,
                ''' + @schema + '.' + @table + ''',
                CAST(MAX(' + QUOTENAME(@pkCol) + ') AS NVARCHAR),
                NULL,
                SYSDATETIME()
            FROM ' + @fullTable + '
            HAVING COUNT(*) > 0;
            ';
            
            EXEC sp_executesql @sql, N'@SnapshotID UNIQUEIDENTIFIER', @SnapshotID = @SnapshotID;
        END
        ELSE
        BEGIN
            -- For tables without identity PKs, create a simple hash of each row
            -- First create a temp table to hold column names
            IF OBJECT_ID('tempdb..#Columns') IS NOT NULL DROP TABLE #Columns;
            CREATE TABLE #Columns (ColumnName SYSNAME);
            
            INSERT INTO #Columns (ColumnName)
            SELECT COLUMN_NAME
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = @schema AND TABLE_NAME = @table
              AND DATA_TYPE NOT IN ('image', 'text', 'ntext', 'sql_variant', 'hierarchyid', 'geometry', 'geography', 'xml', 'timestamp', 'rowversion');
            
            -- Build a simple concatenation of all columns for hashing
            DECLARE @columnList NVARCHAR(MAX) = '';
            SELECT @columnList = STUFF((
                SELECT ' + ISNULL(CAST(' + QUOTENAME(c.ColumnName) + ' AS NVARCHAR(MAX)), '''') + '','''
                FROM #Columns c
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 3, '');

            IF LEN(@columnList) > 0
            BEGIN
                -- Now insert using the built column list
                SET @sql = '
                INSERT INTO dbo.Snapshot_Hashes (SnapshotID, TableName, PrimaryKey, RowHash, SnapshotTime)
                SELECT
                    @SnapshotID,
                    ''' + @schema + '.' + @table + ''',
                    CONVERT(NVARCHAR(36), NEWID()),
                    HASHBYTES(''SHA2_256'', ' + @columnList + '),
                    SYSDATETIME()
                FROM ' + @fullTable + ';';

                EXEC sp_executesql @sql, N'@SnapshotID UNIQUEIDENTIFIER', @SnapshotID = @SnapshotID;
            END
            
            DROP TABLE #Columns;
        END

        SET @pkCol = NULL;
        FETCH NEXT FROM cur INTO @schema, @table;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
