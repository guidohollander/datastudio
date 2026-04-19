# CHANGES Relationships Fix - Root Cause Analysis

## Problem
Replayed cases were not showing CHANGES records in the Be Informed application.

## Root Cause
The relationship definition was incorrect:
- **Wrong**: `CMFRECORD.ID -> CHANGES.CHANGERECORDID`
- **Correct**: `SC_PERSONREGISTRATION_INDIVIDUAL.INDIVIDUALRECORDID -> CHANGES.CHANGERECORDID`

## Analysis

### What We Discovered
In the original captured data:
```
CHANGES.CHANGESRECORDID = 68718
CHANGES.CHANGERECORDID = 5397
CHANGES.TOPICOFCHANGE = 'Individual'
```

The value `5397` is **SC_PERSONREGISTRATION_INDIVIDUAL.INDIVIDUALRECORDID**, NOT CMFRECORD.ID.

### The Confusion
There ARE CMFRECORD entries with RECORDTYPE='Changes':
```
CMFRECORD.ID = 68718
CMFRECORD.RECORDTYPE = 'Changes'
CMFRECORD.CASEID = 175337
```

But these are **framework tracking records**, not the actual records being changed. The CHANGES.CHANGERECORDID points to the **domain record** (the Individual), not the framework tracking record.

### Impact of Wrong Relationship
With the incorrect relationship, the replay framework was:
1. Creating CMFRECORD entries correctly
2. Creating CHANGES entries correctly
3. **BUT** remapping CHANGES.CHANGERECORDID to point to the CMFRECORD IDs instead of the Individual IDs
4. Result: CHANGES.CHANGERECORDID pointed to wrong records, breaking the change tracking

Example of broken replay:
```
Original:
  CHANGES.CHANGESRECORDID = 68718
  CHANGES.CHANGERECORDID = 5397 (Individual)

Replayed (WRONG):
  CHANGES.CHANGESRECORDID = 68873
  CHANGES.CHANGERECORDID = 68872 (CMFRECORD - wrong!)

Should be:
  CHANGES.CHANGESRECORDID = 68873
  CHANGES.CHANGERECORDID = 5428 (new Individual ID)
```

## The Fix

### Removed Incorrect Relationship
```sql
DELETE FROM dbo.MigrationTableRelationships
WHERE ParentTable = 'CMFRECORD'
  AND ParentColumn = 'ID'
  AND ChildTable = 'CHANGES'
  AND ChildColumn = 'CHANGERECORDID';
```

### Added Correct Relationship
```sql
INSERT INTO dbo.MigrationTableRelationships 
  (ParentTable, ParentColumn, ChildTable, ChildColumn, IsActive, Source, Notes)
VALUES 
  ('SC_PERSONREGISTRATION_INDIVIDUAL', 'INDIVIDUALRECORDID', 'CHANGES', 'CHANGERECORDID', 1, 'Analysis', 
   'CHANGES.CHANGERECORDID references SC_PERSONREGISTRATION_INDIVIDUAL.INDIVIDUALRECORDID - the individual being changed');
```

### Kept Correct Relationship
The `CMFRECORD.ID -> CHANGES.MUTATIONRECORDID` relationship was correct and remains:
```sql
-- This one is correct - MUTATIONRECORDID does point to CMFRECORD
CMFRECORD.ID -> CHANGES.MUTATIONRECORDID
```

## Corrected Relationships for CHANGES

After the fix, CHANGES has these relationships:

1. **SC_PERSONREGISTRATION_INDIVIDUAL.INDIVIDUALRECORDID -> CHANGES.CHANGERECORDID**
   - The individual being changed
   
2. **CMFRECORD.ID -> CHANGES.MUTATIONRECORDID**
   - The mutation framework record
   
3. **SC_PERSONREGISTRATION_PROPERTIES.CASEID -> CHANGES.CASEID**
   - The case containing the changes
   
4. **MUTATION.ID -> CHANGES.MUTATIONRECORDID**
   - The mutation record (alternative to CMFRECORD)

## Impact on Replay Order

With the corrected relationships, replay order is now:
1. **SC_PERSONREGISTRATION_PROPERTIES** (case)
2. **SC_PERSONREGISTRATION_INDIVIDUAL** (domain data)
3. **CMFRECORD** (framework records)
4. **MUTATION** (mutation records)
5. **CHANGES** (change records pointing to Individual)

## Next Steps

1. ✅ Relationships corrected in `MigrationTableRelationships`
2. ⏳ User should perform a new replay to test the fix
3. ⏳ Verify CHANGES records appear in Be Informed application
4. ⏳ Verify CHANGES.CHANGERECORDID points to correct Individual IDs

## Verification Query

After replay, verify the fix:
```sql
-- Check replayed CHANGES point to correct Individual IDs
SELECT 
    ch.CHANGESRECORDID,
    ch.CHANGERECORDID,
    ch.TOPICOFCHANGE,
    i.INDIVIDUALRECORDID,
    i.FIRSTNAMES,
    i.SURNAME,
    CASE 
        WHEN i.INDIVIDUALRECORDID IS NOT NULL THEN 'Correct - points to Individual'
        ELSE 'BROKEN - Individual not found'
    END AS Status
FROM CHANGES ch
LEFT JOIN SC_PERSONREGISTRATION_INDIVIDUAL i ON i.INDIVIDUALRECORDID = ch.CHANGERECORDID
WHERE ch.CHANGESRECORDID IN (
    SELECT CAST(NewPkValue AS BIGINT) FROM dbo.MigrationScenarioReplayMap
    WHERE TableName = 'CHANGES'
    ORDER BY NewPkValue DESC
);
```
