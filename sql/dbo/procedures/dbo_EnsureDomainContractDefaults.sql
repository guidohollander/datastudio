SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.EnsureDomainContractDefaults
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainObject WHERE ObjectKey = N'individual')
        INSERT INTO dbo.MigrationDomainObject(ObjectKey, DisplayName, Notes)
        VALUES (N'individual', N'Individual', NULL);

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainComponent WHERE ObjectKey = N'individual' AND ComponentKey = N'individual')
        INSERT INTO dbo.MigrationDomainComponent(ObjectKey, ComponentKey, DisplayName, PhysicalTable, MinOccurs, MaxOccurs, SortOrder, Notes)
        VALUES (N'individual', N'individual', N'Individual', N'SC_PERSONREGISTRATION_INDIVIDUAL', 1, 1, 10, NULL);

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainComponent WHERE ObjectKey = N'individual' AND ComponentKey = N'properties')
        INSERT INTO dbo.MigrationDomainComponent(ObjectKey, ComponentKey, DisplayName, PhysicalTable, MinOccurs, MaxOccurs, SortOrder, Notes)
        VALUES (N'individual', N'properties', N'Properties', N'SC_PERSONREGISTRATION_PROPERTIES', 1, 1, 20, NULL);

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainComponent WHERE ObjectKey = N'individual' AND ComponentKey = N'personIdentification')
        INSERT INTO dbo.MigrationDomainComponent(ObjectKey, ComponentKey, DisplayName, PhysicalTable, MinOccurs, MaxOccurs, SortOrder, Notes)
        VALUES (N'individual', N'personIdentification', N'Person identification', N'SC_PERSONREGISTRATION_PERSONIDENTIFICATION', 0, NULL, 30, NULL);

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainEnum WHERE EnumKey = N'gender')
        INSERT INTO dbo.MigrationDomainEnum(EnumKey, DisplayName, Notes)
        VALUES (N'gender', N'Gender', NULL);

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainEnumValue WHERE EnumKey = N'gender')
    BEGIN
        INSERT INTO dbo.MigrationDomainEnumValue(EnumKey, ValueKey, DisplayName, SortOrder)
        VALUES
            (N'gender', N'Male', N'Male', 10),
            (N'gender', N'Female', N'Female', 20);
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainField WHERE ObjectKey=N'individual' AND ComponentKey=N'individual' AND FieldKey=N'firstNames')
        INSERT INTO dbo.MigrationDomainField(ObjectKey, ComponentKey, FieldKey, PhysicalColumn, DataType, MaxLength, PrecisionValue, ScaleValue, IsRequired, EnumKey, LookupKey, ExampleValue, Notes)
        VALUES (N'individual', N'individual', N'firstNames', N'FIRSTNAMES', N'string', 60, NULL, NULL, 1, NULL, NULL, N'John', NULL);

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainField WHERE ObjectKey=N'individual' AND ComponentKey=N'individual' AND FieldKey=N'surname')
        INSERT INTO dbo.MigrationDomainField(ObjectKey, ComponentKey, FieldKey, PhysicalColumn, DataType, MaxLength, PrecisionValue, ScaleValue, IsRequired, EnumKey, LookupKey, ExampleValue, Notes)
        VALUES (N'individual', N'individual', N'surname', N'SURNAME', N'string', 60, NULL, NULL, 1, NULL, NULL, N'Doe', NULL);

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainField WHERE ObjectKey=N'individual' AND ComponentKey=N'properties' AND FieldKey=N'dateOfBirth')
        INSERT INTO dbo.MigrationDomainField(ObjectKey, ComponentKey, FieldKey, PhysicalColumn, DataType, MaxLength, PrecisionValue, ScaleValue, IsRequired, EnumKey, LookupKey, ExampleValue, Notes)
        VALUES (N'individual', N'properties', N'dateOfBirth', N'DATEOFBIRTH', N'date', NULL, NULL, NULL, 0, NULL, NULL, N'1970-01-01', NULL);

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainField WHERE ObjectKey=N'individual' AND ComponentKey=N'properties' AND FieldKey=N'gender')
        INSERT INTO dbo.MigrationDomainField(ObjectKey, ComponentKey, FieldKey, PhysicalColumn, DataType, MaxLength, PrecisionValue, ScaleValue, IsRequired, EnumKey, LookupKey, ExampleValue, Notes)
        VALUES (N'individual', N'properties', N'gender', N'GENDER', N'string', 13, NULL, NULL, 0, N'gender', NULL, N'Male', NULL);

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainField WHERE ObjectKey=N'individual' AND ComponentKey=N'personIdentification' AND FieldKey=N'identificationNumber')
        INSERT INTO dbo.MigrationDomainField(ObjectKey, ComponentKey, FieldKey, PhysicalColumn, DataType, MaxLength, PrecisionValue, ScaleValue, IsRequired, EnumKey, LookupKey, ExampleValue, Notes)
        VALUES (N'individual', N'personIdentification', N'identificationNumber', N'IDENTIFICATIONNUMBER', N'string', 255, NULL, NULL, 1, NULL, NULL, N'123456789', NULL);

    IF NOT EXISTS (SELECT 1 FROM dbo.MigrationDomainField WHERE ObjectKey=N'individual' AND ComponentKey=N'personIdentification' AND FieldKey=N'identificationType')
        INSERT INTO dbo.MigrationDomainField(ObjectKey, ComponentKey, FieldKey, PhysicalColumn, DataType, MaxLength, PrecisionValue, ScaleValue, IsRequired, EnumKey, LookupKey, ExampleValue, Notes)
        VALUES (N'individual', N'personIdentification', N'identificationType', N'IDENTIFICATIONTYPE', N'string', 255, NULL, NULL, 0, NULL, NULL, N'BSN', NULL);
END
GO
