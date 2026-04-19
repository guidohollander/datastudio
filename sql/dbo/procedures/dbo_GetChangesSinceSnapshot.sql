-- =============================================
-- STEP 4: GET CHANGES SINCE LAST SNAPSHOT
-- =============================================

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.GetChangesSinceSnapshot
    @SnapshotID UNIQUEIDENTIFIER = NULL,
    @TableName NVARCHAR(256) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_WARNINGS ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET ARITHABORT ON;
    SET NUMERIC_ROUNDABORT OFF;
    IF @SnapshotID IS NULL
    BEGIN
        SELECT TOP 1 @SnapshotID = SnapshotID
        FROM dbo.Snapshot_Hashes
        ORDER BY SnapshotTime DESC;
    END

    IF OBJECT_ID('tempdb..#Changes') IS NOT NULL DROP TABLE #Changes;
    CREATE TABLE #Changes (
        TableName NVARCHAR(256) NOT NULL,
        ChangeOrder BIGINT NOT NULL,
        PrimaryKey NVARCHAR(4000) NULL,
        RowHash VARBINARY(32) NULL,
        RowJson NVARCHAR(MAX) NOT NULL
    );

    DECLARE @schema SYSNAME, @table SYSNAME, @fullTable SYSNAME, @pkCol SYSNAME, @sql NVARCHAR(MAX);
    DECLARE cur CURSOR FOR
    SELECT TABLE_SCHEMA, TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_TYPE = 'BASE TABLE'
      AND TABLE_NAME NOT IN ('Snapshot_Hashes', 'MigrationLog')
      AND (
            @TableName IS NULL
            OR (TABLE_SCHEMA + '.' + TABLE_NAME) = @TableName
          );

    OPEN cur;
    FETCH NEXT FROM cur INTO @schema, @table;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @fullTable = QUOTENAME(@schema) + '.' + QUOTENAME(@table);
        SET @pkCol = NULL;
        SELECT TOP 1 @pkCol = COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = @schema AND TABLE_NAME = @table
          AND COLUMNPROPERTY(OBJECT_ID(@schema + '.' + @table), COLUMN_NAME, 'IsIdentity') = 1;

        IF @pkCol IS NOT NULL
        BEGIN
            -- Identity PK: get new rows since latest PK in snapshot
            SET @sql = '
            INSERT INTO #Changes (TableName, ChangeOrder, PrimaryKey, RowHash, RowJson)
            SELECT
                ''' + @schema + '.' + @table + ''' AS TableName,
                CAST(' + QUOTENAME(@pkCol) + ' AS BIGINT) AS ChangeOrder,
                CAST(' + QUOTENAME(@pkCol) + ' AS NVARCHAR(4000)) AS PrimaryKey,
                NULL AS RowHash,
                (SELECT t.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS RowJson
            FROM ' + @fullTable + ' t
            WHERE ' + QUOTENAME(@pkCol) + ' > (
                SELECT ISNULL(MAX(CAST(PrimaryKey AS BIGINT)), 0)
                FROM dbo.Snapshot_Hashes
                WHERE TableName = ''' + @schema + '.' + @table + ''' AND SnapshotID = @SnapshotID
            )
            ORDER BY ' + QUOTENAME(@pkCol) + ';';
        END
        ELSE
        BEGIN
            -- For tables without identity PKs, use the same hash approach as in snapshot
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

            IF LEN(@columnList) = 0
            BEGIN
                SET @sql = '
                INSERT INTO #Changes (TableName, ChangeOrder, PrimaryKey, RowHash, RowJson)
                SELECT
                    ''' + @schema + '.' + @table + ''' AS TableName,
                    0 AS ChangeOrder,
                    NULL AS PrimaryKey,
                    NULL AS RowHash,
                    ''{}'' AS RowJson
                WHERE 1 = 0;';
            END
            ELSE
            BEGIN
                SET @sql = '
                INSERT INTO #Changes (TableName, ChangeOrder, PrimaryKey, RowHash, RowJson)
                SELECT
                    ''' + @schema + '.' + @table + ''' AS TableName,
                    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS ChangeOrder,
                    NULL AS PrimaryKey,
                    HASHBYTES(''SHA2_256'', ' + @columnList + ') AS RowHash,
                    (SELECT t.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS RowJson
                FROM ' + @fullTable + ' t
                WHERE HASHBYTES(''SHA2_256'', ' + @columnList + ') NOT IN (
                    SELECT RowHash FROM dbo.Snapshot_Hashes 
                    WHERE TableName = ''' + @schema + '.' + @table + ''' AND SnapshotID = @SnapshotID
                );';
            END
            
            DROP TABLE #Columns;
        END
        
        BEGIN TRY
            EXEC sp_executesql @sql, N'@SnapshotID UNIQUEIDENTIFIER', @SnapshotID = @SnapshotID;
        END TRY
        BEGIN CATCH
            DECLARE @err NVARCHAR(2048) = ERROR_MESSAGE();
            DECLARE @ctx NVARCHAR(256) = @schema + N'.' + @table;
            DECLARE @msg NVARCHAR(2048) = N'dbo.GetChangesSinceSnapshot failed for ' + @ctx + N': ' + @err;
            THROW 50000, @msg, 1;
        END CATCH
        FETCH NEXT FROM cur INTO @schema, @table;
    END
    CLOSE cur;
    DEALLOCATE cur;

    SELECT TableName, PrimaryKey, RowHash, RowJson
    FROM #Changes
    ORDER BY TableName, ChangeOrder;
END;

GO

