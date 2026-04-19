IF OBJECT_ID(N'dbo.MigrationScenarioSnapshot', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[MigrationScenarioSnapshot]
(
    [SnapshotID] bigint IDENTITY(1,1) NOT NULL,
    [RunID] uniqueidentifier NOT NULL,
    [TableName] nvarchar(128) NOT NULL,
    [PkColumn] nvarchar(128) NOT NULL,
    [PkValue] bigint NOT NULL,
    [RowHash] varbinary(32) NOT NULL,
    [RowJson] nvarchar(max) NOT NULL,
    [CapturedAt] datetime2(7) NOT NULL CONSTRAINT [DF_MigrationScenarioSnapshot_CapturedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_MigrationScenarioSnapshot] PRIMARY KEY CLUSTERED ([SnapshotID] ASC),
    CONSTRAINT [FK_MigrationScenarioSnapshot_Run] FOREIGN KEY ([RunID]) REFERENCES [dbo].[MigrationScenarioRun]([RunID]) ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MigrationScenarioSnapshot_Run_Table' AND object_id = OBJECT_ID('dbo.MigrationScenarioSnapshot'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_MigrationScenarioSnapshot_Run_Table] 
    ON [dbo].[MigrationScenarioSnapshot] ([RunID], [TableName], [PkValue]);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MigrationScenarioSnapshot_Table_PkValue' AND object_id = OBJECT_ID('dbo.MigrationScenarioSnapshot'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_MigrationScenarioSnapshot_Table_PkValue]
    ON [dbo].[MigrationScenarioSnapshot] ([TableName], [PkValue])
    INCLUDE ([RowHash], [RowJson]);
END
GO
