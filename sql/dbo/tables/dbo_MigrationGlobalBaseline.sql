IF OBJECT_ID(N'dbo.MigrationGlobalBaseline', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[MigrationGlobalBaseline]
    (
        [BaselineID] bigint IDENTITY(1,1) NOT NULL,
        [TableName] nvarchar(128) NOT NULL,
        [PkColumn] nvarchar(128) NOT NULL,
        [PkValue] nvarchar(450) NOT NULL,
        [RowHash] varbinary(32) NOT NULL,
        [RowJson] nvarchar(max) NOT NULL,
        [CapturedAt] datetime2(7) NOT NULL CONSTRAINT [DF_MigrationGlobalBaseline_CapturedAt] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_MigrationGlobalBaseline] PRIMARY KEY CLUSTERED ([BaselineID] ASC)
    );
END
ELSE
BEGIN
    -- Alter existing table if PkValue is still bigint
    IF EXISTS (
        SELECT 1 FROM sys.columns 
        WHERE object_id = OBJECT_ID('dbo.MigrationGlobalBaseline') 
        AND name = 'PkValue' 
        AND system_type_id = 127 -- bigint
    )
    BEGIN
        PRINT 'Altering MigrationGlobalBaseline.PkValue from bigint to nvarchar(450)...';
        
        -- Drop dependent index first
        IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MigrationGlobalBaseline_Table_PkValue' AND object_id = OBJECT_ID('dbo.MigrationGlobalBaseline'))
        BEGIN
            DROP INDEX [IX_MigrationGlobalBaseline_Table_PkValue] ON [dbo].[MigrationGlobalBaseline];
        END
        
        -- Alter column type
        ALTER TABLE [dbo].[MigrationGlobalBaseline] 
        ALTER COLUMN [PkValue] nvarchar(450) NOT NULL;
        
        PRINT 'Column altered successfully.';
    END
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MigrationGlobalBaseline_Table_PkValue' AND object_id = OBJECT_ID('dbo.MigrationGlobalBaseline'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_MigrationGlobalBaseline_Table_PkValue]
    ON [dbo].[MigrationGlobalBaseline] ([TableName], [PkValue])
    INCLUDE ([RowHash], [RowJson], [PkColumn]);
END
GO
