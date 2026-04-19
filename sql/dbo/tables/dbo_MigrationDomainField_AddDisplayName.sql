SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- Add DisplayName column to MigrationDomainField if it doesn't exist
IF NOT EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE object_id = OBJECT_ID(N'dbo.MigrationDomainField') 
    AND name = 'DisplayName'
)
BEGIN
    ALTER TABLE dbo.MigrationDomainField
    ADD DisplayName NVARCHAR(200) NULL;
    
    PRINT 'Added DisplayName column to dbo.MigrationDomainField';
END
ELSE
BEGIN
    PRINT 'DisplayName column already exists in dbo.MigrationDomainField';
END
GO
