IF OBJECT_ID(N'dbo.MigrationTableExclusions', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[MigrationTableExclusions]
(
    [ExclusionID] int IDENTITY(1,1) NOT NULL,
    [TablePattern] nvarchar(128) NOT NULL,
    [Reason] nvarchar(500) NULL,
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF_MigrationTableExclusions_CreatedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_MigrationTableExclusions] PRIMARY KEY CLUSTERED ([ExclusionID] ASC),
    CONSTRAINT [UQ_MigrationTableExclusions_Pattern] UNIQUE ([TablePattern])
    );

    INSERT INTO [dbo].[MigrationTableExclusions] ([TablePattern], [Reason]) VALUES
('qrtz_%', 'Quartz scheduler tables - not business data'),
('sys%', 'System tables'),
('%_History', 'Temporal history tables'),
('MigrationScenario%', 'Framework tables'),
('MigrationTable%', 'Framework tables'),
('DataDictionary%', 'Framework tables');
END
GO
