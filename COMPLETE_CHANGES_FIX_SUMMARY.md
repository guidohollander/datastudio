# Complete Fix for CHANGES Records Not Appearing in Replayed Cases

## Root Causes Identified and Fixed

### Issue 1: Incorrect CHANGERECORDID Relationship
**Problem**: CHANGES.CHANGERECORDID was mapped to CMFRECORD.ID instead of SC_PERSONREGISTRATION_INDIVIDUAL.INDIVIDUALRECORDID

**Fix Applied**:
```sql
-- Removed incorrect relationship
DELETE FROM dbo.MigrationTableRelationships
WHERE ParentTable = 'CMFRECORD'
  AND ChildTable = 'CHANGES'
  AND ChildColumn = 'CHANGERECORDID';

-- Added correct relationship
INSERT INTO dbo.MigrationTableRelationships 
  (ParentTable, ParentColumn, ChildTable, ChildColumn, IsActive, Source, Notes)
VALUES 
  ('SC_PERSONREGISTRATION_INDIVIDUAL', 'INDIVIDUALRECORDID', 'CHANGES', 'CHANGERECORDID', 1, 'Analysis', 
   'CHANGES.CHANGERECORDID references SC_PERSONREGISTRATION_INDIVIDUAL.INDIVIDUALRECORDID');
```

### Issue 2: CHANGES.CASEID Not Being Remapped
**Problem**: CHANGES.CASEID had no generator in the domain contract, so it wasn't being remapped during replay. This caused replayed CHANGES records to point to the OLD case ID instead of the NEW case ID.

**Evidence**:
- Original CASEID: 175337
- Replayed CASEID: 175377 (new case)
- CHANGES.CASEID: 175337 (still pointing to old case - WRONG!)
- Result: Case showed 0 changes because CHANGES records pointed to wrong case

**Fix Applied**:
```sql
-- Added generator to CHANGES.CASEID
UPDATE f
SET f.Notes = 'gen: ctx(caseid)'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND c.PhysicalTable = 'CHANGES'
  AND f.PhysicalColumn = 'CASEID';
```

## Complete List of Fixes Applied

### 1. Relationship Fixes
✅ Removed: `CMFRECORD.ID -> CHANGES.CHANGERECORDID` (incorrect)
✅ Added: `SC_PERSONREGISTRATION_INDIVIDUAL.INDIVIDUALRECORDID -> CHANGES.CHANGERECORDID` (correct)
✅ Kept: `CMFRECORD.ID -> CHANGES.MUTATIONRECORDID` (correct)
✅ Kept: `CMFCASE.ID -> CMFRECORD.CASEID` (correct)

### 2. Generator Fixes
✅ Added: `ctx(caseid)` generator to CHANGES.CASEID field
✅ Fixed: All non-FK fields now use `ctx()` by default to preserve original values
✅ Fixed: NULL-valued fields use `ctx()` to preserve NULL
✅ Fixed: literal() fields changed to `ctx()` to preserve original values

### 3. UI Enhancements
✅ Preview step shows FK fields as "will be generated"
✅ Modified fields highlighted with yellow background and MODIFIED badge
✅ Next buttons added at top of Review, Configure, and Preview steps
✅ Commit checkbox defaults to true
✅ Replay tab is default active tab

## How to Test the Fix

### Step 1: Perform a New Replay
**IMPORTANT**: The fixes only affect NEW replays. Old replayed data will still be incorrect.

1. Go to the Replay section in the UI
2. Clear browser cache (Ctrl+Shift+Delete) to ensure fresh contract load
3. Load the contract
4. Configure transformations (all fields should default to ctx())
5. Preview the results
6. Execute the replay with commit=true

### Step 2: Verify CHANGES Records Appear

Run this query to verify the fix worked:

```sql
-- Get the latest replay run
DECLARE @ReplayRunID UNIQUEIDENTIFIER;
SELECT TOP 1 @ReplayRunID = ReplayRunID
FROM dbo.MigrationScenarioReplayRun
ORDER BY CreatedAt DESC;

-- Check replayed case has CHANGES
SELECT 
    p.CASEID AS ReplayedCaseID,
    COUNT(ch.CHANGESRECORDID) AS ChangeCount,
    CASE 
        WHEN COUNT(ch.CHANGESRECORDID) > 0 THEN '✅ SUCCESS - Changes appear!'
        ELSE '❌ FAILED - No changes found'
    END AS Status
FROM SC_PERSONREGISTRATION_PROPERTIES p
LEFT JOIN CHANGES ch ON ch.CASEID = p.CASEID
WHERE p.CASEID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'SC_PERSONREGISTRATION_PROPERTIES'
)
GROUP BY p.CASEID;

-- Verify CHANGES.CHANGERECORDID points to correct Individual
SELECT 
    ch.CHANGESRECORDID,
    ch.CHANGERECORDID,
    ch.TOPICOFCHANGE,
    i.INDIVIDUALRECORDID,
    i.FIRSTNAMES,
    i.SURNAME,
    CASE 
        WHEN i.INDIVIDUALRECORDID IS NOT NULL THEN '✅ Correct - points to Individual'
        ELSE '❌ BROKEN - Individual not found'
    END AS Status
FROM CHANGES ch
LEFT JOIN SC_PERSONREGISTRATION_INDIVIDUAL i ON i.INDIVIDUALRECORDID = ch.CHANGERECORDID
WHERE ch.CHANGESRECORDID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE ReplayRunID = @ReplayRunID AND TableName = 'CHANGES'
);
```

### Step 3: Check in Be Informed Application
1. Open the Be Informed application
2. Navigate to the replayed case
3. Verify that CHANGES records are visible in the case history/timeline
4. Verify that change details show correct information

## Technical Details

### Why CASEID Wasn't Being Remapped
Fields without generators in the domain contract are not included in the replay process. The `dbo.ReplayScenarioRun` stored procedure only processes fields that have generator expressions. Without a generator, CHANGES.CASEID was being inserted with its original value (175337) instead of being remapped to the new case ID (175377).

### Why CHANGERECORDID Was Wrong
The incorrect relationship definition caused the FK remapping logic to remap CHANGES.CHANGERECORDID to CMFRECORD.ID values instead of SC_PERSONREGISTRATION_INDIVIDUAL.INDIVIDUALRECORDID values. This broke the link between CHANGES records and the actual individuals being changed.

### Replay Order with Corrected Relationships
1. SC_PERSONREGISTRATION_PROPERTIES (case)
2. SC_PERSONREGISTRATION_INDIVIDUAL (individuals)
3. CMFCASE (framework case)
4. CMFRECORD (framework records)
5. MUTATION (mutation records)
6. CHANGES (change records - now correctly pointing to individuals and case)

## Files Modified
- `dbo.MigrationTableRelationships` - Corrected CHANGES relationships
- `dbo.MigrationDomainField` - Added ctx(caseid) generator to CHANGES.CASEID
- `ReplayWizard.tsx` - UI enhancements for better UX
- `route.ts` (preview API) - FK field handling in preview

## Success Criteria
After performing a new replay, you should see:
✅ CHANGES records associated with the replayed case (not 0)
✅ CHANGES.CASEID matches the new replayed case ID
✅ CHANGES.CHANGERECORDID points to the new replayed Individual ID
✅ Changes visible in Be Informed application
✅ Change history shows correct details
