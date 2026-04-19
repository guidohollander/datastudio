# Replay Fix Summary

## All Backend Fixes Completed ✅

### 1. Case-Insensitive ctx() Function
- `EvaluateGeneratorExpression` now tries lowercase, uppercase, and original case
- Handles captured data with UPPERCASE keys (e.g., "FIRSTNAMES", "SURNAME")

### 2. Numeric Type Conversion
- `ReplayScenarioRun` uses `TRY_CONVERT` for all numeric types
- `OPENJSON WITH` reads numeric columns as nvarchar, then converts in SELECT

### 3. CHANGES/MUTATION in Contract
- Removed from exclusion list in `GenerateContractFromCapture`
- Modified FK exclusion logic to include necessary fields
- **IMPORTANT**: CHANGERECORDID, MUTATIONRECORDID, CORRECTEDRECORDID are EXCLUDED from contract
  - These are FK fields that need automatic remapping by `ReplayScenarioRun`
  - If they're in the contract, they'll use old RecordID values causing broken links

### 4. API Route Updates (Deployed after Next.js restart)
- `app/api/replay/domain/route.ts` uses `EvaluateGeneratorExpression` for all generators
- `app/api/replay/preview/route.ts` fetches actual captured values for context
- Both routes pass captured row data as context JSON

### 5. Lookup Fields
- All lookup reference fields (COUNTRYOFBIRTH, HOMEADDRESSCOUNTRY, etc.) use `ctx()`
- This ensures exact CODE values from captured data are used

## Current Status

### What's Working ✅
- Preview shows correct data generation with varied names and values
- Records ARE being created during replay (individuals, CHANGES, MUTATION, etc.)
- Individuals appear in `vw_SC_PersonRegistration_Individual` with Active status
- Only 2 Concept individuals exist (original captured data)

### What's Still Broken ❌
- **CHANGES records have broken links** (CHANGERECORDID doesn't match created INDIVIDUALRECORDID)
- This is because the contract still contains CHANGERECORDID from before the fix

## Required Action

### User Must Do This:
1. **In the UI, go to the contract/configuration page**
2. **Click "Regenerate Contract" or similar button**
3. **Verify the contract no longer has these fields in CHANGES component:**
   - ❌ changerecordid
   - ❌ mutationrecordid  
   - ❌ correctedrecordid
4. **The contract SHOULD have these fields in CHANGES:**
   - ✅ caseid
   - ✅ topicofchange
   - ✅ updatetype
5. **Run replay again with the regenerated contract**
6. **Verify CHANGES records now link correctly to created individuals**

## How to Verify Success

Run this SQL to check if CHANGES links are working:

```sql
DECLARE @ReplayRunID UNIQUEIDENTIFIER;
SELECT TOP 1 @ReplayRunID = ReplayRunID
FROM dbo.MigrationScenarioReplayRun
ORDER BY ReplayRunID DESC;

SELECT 
    c.CHANGESRECORDID,
    c.CHANGERECORDID,
    c.TOPICOFCHANGE,
    CASE WHEN i.INDIVIDUALRECORDID IS NOT NULL THEN 'LINKED ✅' ELSE 'BROKEN ❌' END AS Status
FROM CHANGES c
LEFT JOIN SC_PERSONREGISTRATION_INDIVIDUAL i ON i.INDIVIDUALRECORDID = c.CHANGERECORDID
WHERE c.CHANGESRECORDID IN (
    SELECT NewPkValue
    FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID
      AND TableName = 'CHANGES'
)
  AND c.TOPICOFCHANGE = 'Individual';
```

All rows should show "LINKED ✅" status.

## Technical Details

### Why CHANGERECORDID Must Be Excluded

CHANGERECORDID is a foreign key that points to INDIVIDUALRECORDID. During replay:

1. **Wrong approach** (current): Contract includes CHANGERECORDID with `ctx(changerecordid)`
   - This pulls the OLD RecordID from captured data (e.g., 5131)
   - But the NEW individual has a different RecordID (e.g., 5382)
   - Result: CHANGES.CHANGERECORDID = 5131, but no individual with that ID exists → BROKEN

2. **Correct approach** (after fix): Contract excludes CHANGERECORDID
   - `ReplayDomainDataJson` generates data without CHANGERECORDID
   - `ReplayScenarioRun` automatically detects the FK relationship
   - It remaps CHANGERECORDID to point to the newly created INDIVIDUALRECORDID
   - Result: CHANGES.CHANGERECORDID = 5382, individual exists → LINKED ✅

### FK Remapping Logic

`ReplayScenarioRun` has built-in FK remapping that:
- Detects FK relationships from `DataDictionaryRelationshipCandidate`
- Maps old PK values to new PK values in `MigrationScenarioReplayMap`
- Automatically updates FK columns to point to new records

This ONLY works if the FK column is NOT in the contract (i.e., not pre-populated with a value).
