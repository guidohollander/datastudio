SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.CleanupGeneratedIndividuals
    @FirstNamesLike NVARCHAR(200) = N'Maarten%',
    @SurnameLike NVARCHAR(200) = N'Amersfoort%',
    @Commit BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF OBJECT_ID('tempdb..#Individuals') IS NOT NULL DROP TABLE #Individuals;
    IF OBJECT_ID('tempdb..#Cases') IS NOT NULL DROP TABLE #Cases;

    CREATE TABLE #Individuals (
        INDIVIDUALRECORDID BIGINT NOT NULL,
        CASEID BIGINT NULL
    );

    CREATE TABLE #Cases (
        CASEID BIGINT NOT NULL PRIMARY KEY
    );

    INSERT INTO #Individuals(INDIVIDUALRECORDID, CASEID)
    SELECT i.INDIVIDUALRECORDID, i.CASEID
    FROM dbo.SC_PERSONREGISTRATION_INDIVIDUAL i
    WHERE i.FIRSTNAMES LIKE @FirstNamesLike
      AND i.SURNAME LIKE @SurnameLike;

    INSERT INTO #Cases(CASEID)
    SELECT DISTINCT CASEID
    FROM #Individuals;

    SELECT
        (SELECT COUNT(*) FROM #Individuals) AS IndividualCount,
        (SELECT COUNT(*) FROM #Cases) AS CaseCount;

    IF @Commit = 0
        RETURN;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Delete child rows first (best-effort; schema has few enforced FKs)
        DELETE pi
        FROM dbo.SC_PERSONREGISTRATION_PERSONIDENTIFICATION pi
        WHERE EXISTS (SELECT 1 FROM #Cases c WHERE c.CASEID = pi.CASEID);

        DELETE ci
        FROM dbo.SC_PERSONREGISTRATION_CONTACTINFORMATION ci
        WHERE EXISTS (SELECT 1 FROM #Cases c WHERE c.CASEID = ci.CASEID);

        DELETE ha
        FROM dbo.SC_PERSONREGISTRATION_HOMEADDRESS ha
        WHERE EXISTS (SELECT 1 FROM #Cases c WHERE c.CASEID = ha.CASEID);

        DELETE ua
        FROM dbo.SC_USERASSIGNMENT ua
        WHERE EXISTS (SELECT 1 FROM #Cases c WHERE c.CASEID = ua.CASEID);

        DELETE wi
        FROM dbo.SC_WORKITEM wi
        WHERE EXISTS (SELECT 1 FROM #Cases c WHERE c.CASEID = wi.CASEID);

        DELETE tr
        FROM dbo.CMFTRANSITION tr
        WHERE EXISTS (SELECT 1 FROM #Cases c WHERE c.CASEID = tr.CASEID);

        DELETE ev
        FROM dbo.CMFEVENT ev
        WHERE EXISTS (SELECT 1 FROM #Cases c WHERE c.CASEID = ev.CASEID);

        DELETE r
        FROM dbo.CMFRECORD r
        WHERE EXISTS (SELECT 1 FROM #Cases c WHERE c.CASEID = r.CASEID);

        DELETE i
        FROM dbo.SC_PERSONREGISTRATION_INDIVIDUAL i
        WHERE EXISTS (SELECT 1 FROM #Individuals x WHERE x.INDIVIDUALRECORDID = i.INDIVIDUALRECORDID);

        DELETE c
        FROM dbo.CMFCASE c
        WHERE EXISTS (SELECT 1 FROM #Cases x WHERE x.CASEID = c.ID);

        COMMIT TRANSACTION;

        SELECT
            (SELECT COUNT(*) FROM #Individuals) AS DeletedIndividuals,
            (SELECT COUNT(*) FROM #Cases) AS DeletedCases;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
