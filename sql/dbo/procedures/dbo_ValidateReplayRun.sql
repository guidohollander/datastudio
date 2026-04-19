SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.ValidateReplayRun
    @ReplayRunID UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @ReplayRunID IS NULL
    BEGIN
        IF @Notes IS NULL
            THROW 50000, N'Either @ReplayRunID or @Notes must be provided.', 1;

        SELECT TOP 1 @ReplayRunID = ReplayRunID
        FROM dbo.MigrationScenarioReplayRun
        WHERE Notes = @Notes
        ORDER BY CreatedAt DESC;
    END

    IF @ReplayRunID IS NULL
        THROW 50000, N'Could not resolve ReplayRunID.', 1;

    ;WITH
    CaseMap AS (
        SELECT NewPkValue AS NewCaseId
        FROM dbo.MigrationScenarioReplayMap
        WHERE ReplayRunID = @ReplayRunID
          AND TableName = N'CMFCASE'
    ),
    IndMap AS (
        SELECT NewPkValue AS NewIndId
        FROM dbo.MigrationScenarioReplayMap
        WHERE ReplayRunID = @ReplayRunID
          AND TableName = N'SC_PERSONREGISTRATION_INDIVIDUAL'
    )
    SELECT
        @ReplayRunID AS ReplayRunID,
        (SELECT COUNT(*) FROM IndMap) AS IndividualsMapped,
        (SELECT COUNT(*) FROM CaseMap) AS CasesMapped,
        (
            SELECT COUNT(*)
            FROM IndMap im
            JOIN dbo.SC_PERSONREGISTRATION_INDIVIDUAL i
              ON i.INDIVIDUALRECORDID = im.NewIndId
            WHERE EXISTS (
                SELECT 1
                FROM CaseMap cm
                WHERE cm.NewCaseId = TRY_CONVERT(BIGINT, i.CASEID)
            )
        ) AS IndividualsWhoseCaseIdMatchesCaseMap;

    ;WITH
    CaseMap AS (
        SELECT NewPkValue AS NewCaseId
        FROM dbo.MigrationScenarioReplayMap
        WHERE ReplayRunID = @ReplayRunID
          AND TableName = N'CMFCASE'
    ),
    IndMap AS (
        SELECT NewPkValue AS NewIndId
        FROM dbo.MigrationScenarioReplayMap
        WHERE ReplayRunID = @ReplayRunID
          AND TableName = N'SC_PERSONREGISTRATION_INDIVIDUAL'
    )
    SELECT TOP 20
        i.INDIVIDUALRECORDID AS NewIndividualRecordId,
        i.CASEID AS NewCaseIdOnIndividual,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM CaseMap cm
                WHERE cm.NewCaseId = TRY_CONVERT(BIGINT, i.CASEID)
            ) THEN 1 ELSE 0
        END AS CaseIdMatchesReplayCaseMap
    FROM IndMap im
    JOIN dbo.SC_PERSONREGISTRATION_INDIVIDUAL i
      ON i.INDIVIDUALRECORDID = im.NewIndId
    ORDER BY i.INDIVIDUALRECORDID DESC;
END
GO
