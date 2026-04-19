# Codex Context: Add Custom Field Labels to Settings Export API

## Problem Statement

The user has a settings export API that returns JSON with settings metadata and fields. They set a custom label **"Appeal submission deadline days after notice"** for field `APPEAL_SUBMISSION_DEADLINE_DAYS_AFTER_NOTICE` in a fields editor UI, but this custom label is **not appearing** in the export API response.

## What Was Already Done (Not the Right System)

I previously modified the **contract/migration domain API** system, adding `DisplayName` support to:
- `dbo.MigrationDomainField` table (added DisplayName column)
- `dbo.GenerateDomainContractJson` stored procedure
- `/api/contract/route.ts` API endpoint

However, the user's issue is with a **different API** - a settings/dictionary export API that has a different JSON structure.

## Current Export JSON Structure (Missing Custom Labels)

```json
[
  {
    "SettingId": 22,
    "SettingKey": "PT_APPEAL_DEADLINES",
    "FriendlyName": "Appeal Deadlines",
    "CategoryCode": "PropertyTax/Compliance",
    "Description": "Deadlines for submitting appeals against property tax assessments.",
    "IsMasterData": false,
    "TemporalType": "None",
    "Fields": [
      {
        "FieldName": "_GUID",
        "DataType": "uniqueidentifier",
        "IsMandatory": true,
        "IsKey": true,
        "IsGroupingKey": false,
        "IsMigrateKey": false,
        "IsLookup": 0
      },
      {
        "FieldName": "APPEAL_SUBMISSION_DEADLINE_DAYS_AFTER_NOTICE",
        "DataType": "int",
        "IsMandatory": true,
        "IsKey": false,
        "IsGroupingKey": false,
        "IsMigrateKey": false,
        "IsLookup": 0
        // ❌ MISSING: "DisplayName": "Appeal submission deadline days after notice"
      },
      {
        "FieldName": "ALLOW_LATE_APPEALS",
        "DataType": "bit",
        "IsMandatory": true,
        "IsKey": false,
        "IsGroupingKey": false,
        "IsMigrateKey": false,
        "IsLookup": 0
      },
      {
        "FieldName": "LATE_APPEAL_MAX_DAYS",
        "DataType": "int",
        "IsMandatory": true,
        "IsKey": false,
        "IsGroupingKey": false,
        "IsMigrateKey": false,
        "IsLookup": 0
      }
    ],
    "Data": [
      {
        "_GUID": "a34deb1e-54cb-4c05-9297-d50aa67f54f9",
        "ALLOW_LATE_APPEALS": "false",
        "APPEAL_SUBMISSION_DEADLINE_DAYS_AFTER_NOTICE": "30",
        "LATE_APPEAL_MAX_DAYS": "0"
      }
    ],
    "TotalCount": 1,
    "Offset": 0,
    "Limit": 1000,
    "LastModified": "2026-03-05T11:26:29.4233333"
  }
]
```

## Expected Behavior

Each field in the `Fields` array should include a `DisplayName` property with the custom label:

```json
{
  "FieldName": "APPEAL_SUBMISSION_DEADLINE_DAYS_AFTER_NOTICE",
  "DisplayName": "Appeal submission deadline days after notice",  // ✅ Should be here
  "DataType": "int",
  "IsMandatory": true,
  "IsKey": false,
  "IsGroupingKey": false,
  "IsMigrateKey": false,
  "IsLookup": 0
}
```

## What Needs to Be Found

1. **Settings Export API Endpoint**
   - Where is the API that generates this JSON response?
   - Search for endpoints that return `SettingKey`, `FriendlyName`, `Fields` array
   - Likely patterns: `/api/settings`, `/api/dictionary`, `/api/export`, `/api/admin/settings`

2. **Database Tables**
   - What table stores the settings definitions? (e.g., `GenericSetting`, `GSF_Setting`, `dbo.Setting`)
   - What table stores the field metadata? (e.g., `GenericSettingField`, `GSF_SettingField`, `dbo.SettingField`)
   - Does the field table have a column for custom labels? (e.g., `DisplayName`, `Label`, `FriendlyName`, `CustomLabel`)

3. **Fields Editor UI**
   - User mentioned they set the label in "the fields editor"
   - Where is this UI component? (likely in `/app/dictionary/` or `/app/admin/`)
   - What API does it call to save custom labels?

## Search Strategy

### 1. Find the API Endpoint
```bash
# Search for the JSON structure
grep -r "SettingKey" --include="*.ts" --include="*.tsx" --exclude-dir=node_modules
grep -r "FriendlyName.*CategoryCode" --include="*.ts" --include="*.tsx" --exclude-dir=node_modules
grep -r "IsMasterData.*TemporalType" --include="*.ts" --include="*.tsx" --exclude-dir=node_modules
```

### 2. Find Database Tables
```bash
# Search for setting-related tables
grep -r "CREATE TABLE.*Setting" --include="*.sql"
grep -r "GenericSetting\|GSF_Setting" --include="*.sql"
grep -r "SettingField\|Setting.*Field" --include="*.sql"
```

### 3. Find the Fields Editor
```bash
# Search for field editor components
find . -name "*field*editor*" -o -name "*setting*editor*"
grep -r "field.*editor\|edit.*field" --include="*.tsx" --exclude-dir=node_modules
```

## Implementation Steps (Once Found)

### Step 1: Verify Database Column Exists
Check if the settings field table has a `DisplayName` or similar column:
```sql
SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME LIKE '%Setting%Field%'
AND COLUMN_NAME LIKE '%Display%' OR COLUMN_NAME LIKE '%Label%' OR COLUMN_NAME LIKE '%Friendly%';
```

If not, add it:
```sql
ALTER TABLE [SettingFieldTable] 
ADD DisplayName NVARCHAR(200) NULL;
```

### Step 2: Update the Export API
Modify the API endpoint to include `DisplayName` in the Fields array:
```typescript
// Before
{
  FieldName: field.FieldName,
  DataType: field.DataType,
  IsMandatory: field.IsMandatory,
  ...
}

// After
{
  FieldName: field.FieldName,
  DisplayName: field.DisplayName || null,  // ✅ Add this
  DataType: field.DataType,
  IsMandatory: field.IsMandatory,
  ...
}
```

### Step 3: Update Database Query/Procedure
If the API calls a stored procedure, update it to SELECT the DisplayName column:
```sql
SELECT 
  FieldName,
  DisplayName,  -- ✅ Add this
  DataType,
  IsMandatory,
  ...
FROM [SettingFieldTable]
```

### Step 4: Verify Fields Editor Saves Labels
Ensure the fields editor UI is saving to the DisplayName column when user edits labels.

## Files Modified So Far (Wrong System)

These were for the contract/migration domain API (not the settings API):
- `c:\dev\db\snapshot\sql\dbo\tables\dbo_MigrationDomainField_AddDisplayName.sql`
- `c:\dev\db\snapshot\sql\dbo\procedures\dbo_GenerateDomainContractJson.sql`
- `c:\dev\db\snapshot\ui\scenario-studio\app\api\contract\route.ts`

## Project Structure

```
c:\dev\db\snapshot\
├── sql\
│   └── dbo\
│       ├── tables\
│       └── procedures\
└── ui\scenario-studio\
    └── app\
        ├── admin\
        ├── api\
        │   ├── admin\
        │   ├── contract\
        │   ├── runs\
        │   └── scenarios\
        ├── dictionary\
        └── dataset\
```

## Key Questions to Answer

1. **Where is the settings export API?** (Not found in initial search)
2. **What are the actual table names?** (GenericSetting? GSF_Setting? Something else?)
3. **Is this in the same codebase?** (Or external service/different repo?)
4. **Where is the fields editor UI?** (To verify it's saving labels correctly)

## Next Steps for Codex

1. Search for the API endpoint that returns the JSON structure shown above
2. Identify the database tables for settings and fields
3. Check if DisplayName column exists in the field table
4. Update the export API to include DisplayName in response
5. Verify the fields editor is saving labels correctly
6. Test with the specific field: `APPEAL_SUBMISSION_DEADLINE_DAYS_AFTER_NOTICE` for setting `PT_APPEAL_DEADLINES`

## Success Criteria

When exporting settings for `PT_APPEAL_DEADLINES`, the field `APPEAL_SUBMISSION_DEADLINE_DAYS_AFTER_NOTICE` should show:
```json
{
  "FieldName": "APPEAL_SUBMISSION_DEADLINE_DAYS_AFTER_NOTICE",
  "DisplayName": "Appeal submission deadline days after notice",
  "DataType": "int",
  ...
}
```
