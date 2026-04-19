SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.CreateScenario
    @ScenarioName NVARCHAR(200),
    @Notes NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ScenarioID INT;

    SELECT @ScenarioID = ScenarioID
    FROM dbo.MigrationScenario
    WHERE Name = @ScenarioName;

    IF @ScenarioID IS NULL
    BEGIN
        INSERT INTO dbo.MigrationScenario(Name, Notes)
        VALUES (@ScenarioName, @Notes);

        SET @ScenarioID = CAST(SCOPE_IDENTITY() AS INT);
    END

    SELECT @ScenarioID AS ScenarioID;
END
GO
