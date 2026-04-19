SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.SeedReferenceData
AS
BEGIN
    SET NOCOUNT ON;

    -- Clear existing data
    DELETE FROM dbo.ReferenceDataPool;

    -- Dutch Male First Names
    INSERT INTO dbo.ReferenceDataPool (PoolName, Category, Value, Weight) VALUES
    ('firstNames.male', 'name', 'Jan', 10),
    ('firstNames.male', 'name', 'Piet', 10),
    ('firstNames.male', 'name', 'Klaas', 8),
    ('firstNames.male', 'name', 'Henk', 8),
    ('firstNames.male', 'name', 'Willem', 7),
    ('firstNames.male', 'name', 'Daan', 9),
    ('firstNames.male', 'name', 'Lars', 8),
    ('firstNames.male', 'name', 'Thijs', 7),
    ('firstNames.male', 'name', 'Bram', 7),
    ('firstNames.male', 'name', 'Sven', 6),
    ('firstNames.male', 'name', 'Luuk', 6),
    ('firstNames.male', 'name', 'Tim', 6),
    ('firstNames.male', 'name', 'Tom', 6),
    ('firstNames.male', 'name', 'Bas', 5),
    ('firstNames.male', 'name', 'Ruben', 5);

    -- Dutch Female First Names
    INSERT INTO dbo.ReferenceDataPool (PoolName, Category, Value, Weight) VALUES
    ('firstNames.female', 'name', 'Anna', 10),
    ('firstNames.female', 'name', 'Emma', 10),
    ('firstNames.female', 'name', 'Sophie', 9),
    ('firstNames.female', 'name', 'Lisa', 8),
    ('firstNames.female', 'name', 'Eva', 8),
    ('firstNames.female', 'name', 'Sara', 7),
    ('firstNames.female', 'name', 'Julia', 7),
    ('firstNames.female', 'name', 'Lotte', 7),
    ('firstNames.female', 'name', 'Fleur', 6),
    ('firstNames.female', 'name', 'Iris', 6),
    ('firstNames.female', 'name', 'Anouk', 6),
    ('firstNames.female', 'name', 'Sanne', 6),
    ('firstNames.female', 'name', 'Femke', 5),
    ('firstNames.female', 'name', 'Noa', 5),
    ('firstNames.female', 'name', 'Mila', 5);

    -- Dutch Surnames
    INSERT INTO dbo.ReferenceDataPool (PoolName, Category, Value, Weight) VALUES
    ('surnames.dutch', 'name', 'de Jong', 10),
    ('surnames.dutch', 'name', 'Jansen', 10),
    ('surnames.dutch', 'name', 'de Vries', 9),
    ('surnames.dutch', 'name', 'van den Berg', 9),
    ('surnames.dutch', 'name', 'van Dijk', 8),
    ('surnames.dutch', 'name', 'Bakker', 8),
    ('surnames.dutch', 'name', 'Janssen', 7),
    ('surnames.dutch', 'name', 'Visser', 7),
    ('surnames.dutch', 'name', 'Smit', 7),
    ('surnames.dutch', 'name', 'Meijer', 6),
    ('surnames.dutch', 'name', 'de Boer', 6),
    ('surnames.dutch', 'name', 'Mulder', 6),
    ('surnames.dutch', 'name', 'de Groot', 5),
    ('surnames.dutch', 'name', 'Bos', 5),
    ('surnames.dutch', 'name', 'Vos', 5),
    ('surnames.dutch', 'name', 'Peters', 5),
    ('surnames.dutch', 'name', 'Hendriks', 4),
    ('surnames.dutch', 'name', 'van Leeuwen', 4),
    ('surnames.dutch', 'name', 'Dekker', 4),
    ('surnames.dutch', 'name', 'Brouwer', 4);

    -- Dutch Cities
    INSERT INTO dbo.ReferenceDataPool (PoolName, Category, Value, Weight) VALUES
    ('cities.netherlands', 'location', 'Amsterdam', 10),
    ('cities.netherlands', 'location', 'Rotterdam', 9),
    ('cities.netherlands', 'location', 'Den Haag', 9),
    ('cities.netherlands', 'location', 'Utrecht', 8),
    ('cities.netherlands', 'location', 'Eindhoven', 7),
    ('cities.netherlands', 'location', 'Groningen', 6),
    ('cities.netherlands', 'location', 'Tilburg', 6),
    ('cities.netherlands', 'location', 'Almere', 5),
    ('cities.netherlands', 'location', 'Breda', 5),
    ('cities.netherlands', 'location', 'Nijmegen', 5),
    ('cities.netherlands', 'location', 'Apeldoorn', 4),
    ('cities.netherlands', 'location', 'Haarlem', 4),
    ('cities.netherlands', 'location', 'Arnhem', 4),
    ('cities.netherlands', 'location', 'Zaanstad', 3),
    ('cities.netherlands', 'location', 'Amersfoort', 4);

    -- Countries (ISO codes)
    INSERT INTO dbo.ReferenceDataPool (PoolName, Category, Value, Weight, Metadata) VALUES
    ('countries.iso', 'location', 'NL', 50, '{"name":"Netherlands"}'),
    ('countries.iso', 'location', 'BE', 10, '{"name":"Belgium"}'),
    ('countries.iso', 'location', 'DE', 8, '{"name":"Germany"}'),
    ('countries.iso', 'location', 'GB', 5, '{"name":"United Kingdom"}'),
    ('countries.iso', 'location', 'FR', 5, '{"name":"France"}'),
    ('countries.iso', 'location', 'ES', 3, '{"name":"Spain"}'),
    ('countries.iso', 'location', 'IT', 3, '{"name":"Italy"}'),
    ('countries.iso', 'location', 'PL', 4, '{"name":"Poland"}'),
    ('countries.iso', 'location', 'TR', 3, '{"name":"Turkey"}'),
    ('countries.iso', 'location', 'MA', 2, '{"name":"Morocco"}');

    -- Occupations
    INSERT INTO dbo.ReferenceDataPool (PoolName, Category, Value, Weight) VALUES
    ('occupations', 'profession', 'Software Developer', 8),
    ('occupations', 'profession', 'Teacher', 7),
    ('occupations', 'profession', 'Nurse', 7),
    ('occupations', 'profession', 'Engineer', 6),
    ('occupations', 'profession', 'Manager', 6),
    ('occupations', 'profession', 'Sales Representative', 5),
    ('occupations', 'profession', 'Accountant', 5),
    ('occupations', 'profession', 'Designer', 4),
    ('occupations', 'profession', 'Consultant', 5),
    ('occupations', 'profession', 'Doctor', 4),
    ('occupations', 'profession', 'Lawyer', 3),
    ('occupations', 'profession', 'Chef', 3),
    ('occupations', 'profession', 'Mechanic', 4),
    ('occupations', 'profession', 'Electrician', 4),
    ('occupations', 'profession', 'Plumber', 3),
    ('occupations', 'profession', 'Retail Worker', 6),
    ('occupations', 'profession', 'Administrative Assistant', 5),
    ('occupations', 'profession', 'Student', 8),
    ('occupations', 'profession', 'Retired', 5),
    ('occupations', 'profession', 'Unemployed', 2);

    -- Gender values
    INSERT INTO dbo.ReferenceDataPool (PoolName, Category, Value, Weight) VALUES
    ('gender', 'demographic', 'Male', 51),
    ('gender', 'demographic', 'Female', 49);

    -- Resident status
    INSERT INTO dbo.ReferenceDataPool (PoolName, Category, Value, Weight) VALUES
    ('resident', 'status', 'Birth', 70),
    ('resident', 'status', 'Immigration', 20),
    ('resident', 'status', 'Naturalization', 10);

    -- Email domains
    INSERT INTO dbo.ReferenceDataPool (PoolName, Category, Value, Weight) VALUES
    ('emailDomains', 'contact', 'gmail.com', 30),
    ('emailDomains', 'contact', 'hotmail.com', 20),
    ('emailDomains', 'contact', 'outlook.com', 15),
    ('emailDomains', 'contact', 'yahoo.com', 10),
    ('emailDomains', 'contact', 'ziggo.nl', 8),
    ('emailDomains', 'contact', 'kpn.nl', 7),
    ('emailDomains', 'contact', 'xs4all.nl', 5),
    ('emailDomains', 'contact', 'live.nl', 5);

    PRINT 'Reference data seeded successfully';
END
GO
