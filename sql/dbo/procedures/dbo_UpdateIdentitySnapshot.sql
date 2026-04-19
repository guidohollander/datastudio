CREATE OR ALTER PROCEDURE dbo.UpdateIdentitySnapshot
AS
BEGIN
    SET NOCOUNT ON;

    -- Ensure snapshot table exists
    IF OBJECT_ID('dbo.IdentitySnapshot') IS NULL
    BEGIN
        CREATE TABLE dbo.IdentitySnapshot (
            TableName SYSNAME PRIMARY KEY,
            IdentityColumn SYSNAME,
            LastIdentityValue BIGINT,
            SnapshotTime DATETIME2 DEFAULT GETUTCDATE()
        );
    END

    DECLARE @table SYSNAME, @column SYSNAME, @cmd NVARCHAR(MAX);

    DECLARE cur CURSOR FOR
    SELECT t.name, c.name
    FROM sys.tables t
    JOIN sys.columns c ON t.object_id = c.object_id
    WHERE SCHEMA_NAME(t.schema_id) = 'dbo'
      AND c.is_identity = 1;

    OPEN cur
    FETCH NEXT FROM cur INTO @table, @column;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @cmd = '
DECLARE @maxval BIGINT;
SELECT @maxval = MAX([' + @column + ']) FROM dbo.[' + @table + '];

MERGE dbo.IdentitySnapshot AS target
USING (SELECT ''' + @table + ''' AS TableName, ''' + @column + ''' AS IdentityColumn, @maxval AS LastIdentityValue) AS source
ON target.TableName = source.TableName
WHEN MATCHED THEN 
    UPDATE SET LastIdentityValue = source.LastIdentityValue,
               SnapshotTime = GETUTCDATE()
WHEN NOT MATCHED THEN 
    INSERT (TableName, IdentityColumn, LastIdentityValue)
    VALUES (source.TableName, source.IdentityColumn, source.LastIdentityValue);';

        EXEC sp_executesql @cmd;

        FETCH NEXT FROM cur INTO @table, @column;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;

GO

