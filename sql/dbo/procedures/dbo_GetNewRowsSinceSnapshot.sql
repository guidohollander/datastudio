SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.GetNewRowsSinceSnapshot
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE dbo.NewRowsSinceSnapshotResult;

    DECLARE @sql NVARCHAR(MAX) = '';
    DECLARE @stmt NVARCHAR(MAX);
    DECLARE @table SYSNAME, @idcol SYSNAME;
    DECLARE @lastval BIGINT;

    DECLARE cur CURSOR FOR
    SELECT TableName, IdentityColumn, COALESCE(LastIdentityValue, 0)
    FROM dbo.IdentitySnapshot;

    OPEN cur;
    FETCH NEXT FROM cur INTO @table, @idcol, @lastval;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF OBJECT_ID(N'dbo.' + QUOTENAME(@table), N'U') IS NOT NULL
           AND COL_LENGTH(N'dbo.' + QUOTENAME(@table), @idcol) IS NOT NULL
           AND COLUMNPROPERTY(OBJECT_ID(N'dbo.' + QUOTENAME(@table)), @idcol, 'IsIdentity') = 1
        BEGIN
            SET @stmt = '
            SELECT 
                ''' + @table + ''' AS TableName,
                CAST(' + QUOTENAME(@idcol) + ' AS BIGINT) AS NewIdentityValue,
                GETUTCDATE() AS FoundAt
            FROM dbo.' + QUOTENAME(@table) + '
            WHERE ' + QUOTENAME(@idcol) + ' > ' + CAST(@lastval AS VARCHAR(30)) + CHAR(13);

            SET @sql += IIF(LEN(@sql) > 0, 'UNION ALL' + CHAR(13), '') + @stmt;
        END

        FETCH NEXT FROM cur INTO @table, @idcol, @lastval;
    END

    CLOSE cur;
    DEALLOCATE cur;

    IF LEN(@sql) > 0
    BEGIN
        SET @sql = '
        INSERT INTO dbo.NewRowsSinceSnapshotResult (TableName, NewIdentityValue, FoundAt)
        ' + @sql;

        EXEC sp_executesql @sql;
    END
    ELSE
    BEGIN
        PRINT 'No identity-tracked tables found.';
    END
      
    SELECT * FROM dbo.NewRowsSinceSnapshotResult;
   
END;
