# CHANGES, MUTATION, and CMFRECORD Relationship Analysis

## Problem Statement
Replayed data was not showing changes in the Be Informed application, even though CHANGES and MUTATION records were being created. The issue was that the framework relationships were incomplete.

## How It Works in the Original Data

### 1. CMFRECORD Table
- **Purpose**: Framework table that tracks all records in the case management system
- **Key Fields**:
  - `ID` (PK): Unique identifier for the record
  - `CASEID` (FK): References CMFCASE.ID
  - `RECORDTYPE`: Type of record ('Changes', 'Mutation', 'Individual', etc.)

### 2. CHANGES Table
- **Purpose**: Tracks individual changes made to a case
- **Key Fields**:
  - `CHANGESRECORDID` (PK): Unique identifier for the change
  - `CASEID` (FK): References SC_PERSONREGISTRATION_PROPERTIES.ID (the case)
  - `CHANGERECORDID` (FK): **References CMFRECORD.ID** - the record being changed
  - `MUTATIONRECORDID` (FK): **References CMFRECORD.ID** - the mutation record
  - `TOPICOFCHANGE`: What was changed (e.g., 'Individual')

### 3. MUTATION Table
- **Purpose**: Groups multiple changes together
- **Key Fields**:
  - `MUTATIONRECORDID` (PK): Unique identifier for the mutation
  - `CASEID` (FK): References SC_PERSONREGISTRATION_PROPERTIES.ID

## Critical Discovery
**CHANGES.CHANGERECORDID does NOT point to SC_PERSONREGISTRATION_INDIVIDUAL.INDIVIDUALRECORDID**

Instead, it points to **CMFRECORD.ID** where CMFRECORD.RECORDTYPE = 'Changes'

This means:
1. When a change is made to an Individual, a CMFRECORD entry is created with RECORDTYPE='Changes'
2. The CHANGES.CHANGERECORDID points to this CMFRECORD entry
3. The Be Informed application uses CMFRECORD to display changes in the UI

## What Was Missing

### Before Fix
- CMFRECORD was captured but not properly related to CHANGES
- Replay order did not guarantee CMFRECORD was created before CHANGES
- CHANGES.CHANGERECORDID pointed to wrong IDs after replay
- Changes were invisible in Be Informed application

### After Fix
Added three critical relationships to `MigrationTableRelationships`:

1. **CMFCASE -> CMFRECORD**
   - `CMFCASE.ID` -> `CMFRECORD.CASEID`
   - Ensures case is created before its records

2. **CMFRECORD -> CHANGES (CHANGERECORDID)**
   - `CMFRECORD.ID` -> `CHANGES.CHANGERECORDID`
   - Ensures CMFRECORD is created before CHANGES
   - Enables FK remapping so CHANGES points to new CMFRECORD.ID

3. **CMFRECORD -> CHANGES (MUTATIONRECORDID)**
   - `CMFRECORD.ID` -> `CHANGES.MUTATIONRECORDID`
   - Ensures mutation CMFRECORD is created before CHANGES
   - Enables FK remapping for mutation references

## How Replay Order Works

The `dbo.ReplayScenarioRun` stored procedure uses `MigrationTableRelationships` to build a dependency graph:

```sql
FROM dbo.MigrationTableRelationships r
WHERE r.IsActive = 1
  AND EXISTS (SELECT 1 FROM #Tables t WHERE t.TableName = r.ParentTable)
  AND EXISTS (SELECT 1 FROM #Tables t WHERE t.TableName = r.ChildTable)
```

With the new relationships, the replay order is now:
1. **CMFCASE** (case)
2. **CMFRECORD** (framework records for the case)
3. **SC_PERSONREGISTRATION_INDIVIDUAL** (domain data)
4. **CHANGES** (change records pointing to CMFRECORD)
5. **MUTATION** (mutation records)

## Verification

### Check Relationships Are Active
```sql
SELECT 
    ParentTable,
    ParentColumn,
    ChildTable,
    ChildColumn,
    Source,
    Notes
FROM dbo.MigrationTableRelationships
WHERE (ParentTable IN ('CMFRECORD', 'CMFCASE') OR ChildTable IN ('CMFRECORD', 'CHANGES'))
  AND IsActive = 1
ORDER BY ParentTable, ChildTable;
```

### Verify Replayed Data
```sql
-- Check replayed CMFRECORD
SELECT r.ID, r.CASEID, r.RECORDTYPE
FROM CMFRECORD r
WHERE r.ID IN (
    SELECT NewPkValue FROM dbo.MigrationScenarioReplayMap
    WHERE TableName = 'CMFRECORD'
);

-- Check replayed CHANGES point to replayed CMFRECORD
SELECT 
    ch.CHANGESRECORDID,
    ch.CHANGERECORDID,
    r.ID AS CMFRecordID,
    r.RECORDTYPE,
    CASE 
        WHEN r.ID IS NOT NULL THEN 'Correct - points to replayed CMFRECORD'
        ELSE 'BROKEN - does not point to replayed CMFRECORD'
    END AS Status
FROM CHANGES ch
LEFT JOIN CMFRECORD r ON r.ID = ch.CHANGERECORDID
WHERE ch.CHANGESRECORDID IN (
    SELECT NewPkValue FROM dbo.MigrationScenarioReplayMap
    WHERE TableName = 'CHANGES'
);
```

## Impact on Analysis Step

The relationships are now visible in the Analysis step UI because:
1. They're stored in `MigrationTableRelationships` (global registry)
2. `dbo.CaptureScenarioRelationships` copies them to `MigrationScenarioRelationship` for each run
3. The UI queries `MigrationScenarioRelationship` to display the relationship graph

## Impact on Replay

The relationships ensure:
1. **Correct order**: CMFRECORD created before CHANGES
2. **FK remapping**: CHANGES.CHANGERECORDID updated to point to new CMFRECORD.ID
3. **Data integrity**: All references remain valid after replay
4. **UI visibility**: Changes appear in Be Informed application

## Next Steps

1. ✅ Relationships added to `MigrationTableRelationships`
2. ✅ Relationships will be used in replay ordering
3. ⏳ Verify relationships appear in Analysis step UI
4. ⏳ Test replay and verify changes appear in Be Informed application
