-- =============================================
-- STEP 4: DETECT NEW ROWS (SINCE LAST SNAPSHOT)
-- =============================================

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.DetectSnapshotBasedRelationships
    @SnapshotID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @SnapshotID IS NULL
    BEGIN
        SELECT TOP 1 @SnapshotID = SnapshotID
        FROM dbo.Snapshot_Hashes
        ORDER BY SnapshotTime DESC;
    END

    DECLARE @schema SYSNAME, @table SYSNAME, @fullTable SYSNAME;
    DECLARE @sql NVARCHAR(MAX), @pkCol SYSNAME;

    DECLARE cur CURSOR FOR
    SELECT TABLE_SCHEMA, TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_TYPE = 'BASE TABLE'
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
            SET @sql = '
            SELECT ''' + @schema + '.' + @table + ''' AS TableName, CAST(' + QUOTENAME(@pkCol) + ' AS NVARCHAR) AS PrimaryKey
            FROM ' + @fullTable + ' t
            WHERE ' + QUOTENAME(@pkCol) + ' > (
                SELECT CAST(MAX(PrimaryKey) AS BIGINT)
                FROM dbo.Snapshot_Hashes
                WHERE TableName = ''' + @schema + '.' + @table + ''' AND SnapshotID = @SnapshotID
            );';
            EXEC sp_executesql @sql, N'@SnapshotID UNIQUEIDENTIFIER', @SnapshotID = @SnapshotID;
        END

        FETCH NEXT FROM cur INTO @schema, @table;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
