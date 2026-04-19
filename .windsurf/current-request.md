# Current Request: Add Custom Field Labels to Settings Export API

## Feature Description
The user has a settings export API that returns JSON with settings metadata and fields. They set a custom label "Appeal submission deadline days after notice" for field `APPEAL_SUBMISSION_DEADLINE_DAYS_AFTER_NOTICE` in the fields editor, but this custom label is not appearing in the export API response.

## Context
This is about a **settings/dictionary export API**, NOT the contract/migration domain API that was just modified. The JSON structure shows:
- `SettingKey`: "PT_APPEAL_DEADLINES"
- `FriendlyName`: "Appeal Deadlines"
- `Fields`: Array with `FieldName`, `DataType`, etc.

The custom label should appear in the Fields array but currently doesn't.

## Functional Requirements

### FR-1: Locate the Settings Export API
- Find where the settings export API is implemented
- Identify the database tables/procedures that store settings and field metadata
- Understand where custom field labels are stored

### FR-2: Add Custom Label to API Response
- Include the custom field label in the Fields array of the export response
- The label "Appeal submission deadline days after notice" should appear for field `APPEAL_SUBMISSION_DEADLINE_DAYS_AFTER_NOTICE`
- Add a property like `DisplayName`, `Label`, or `FriendlyName` to each field object

### FR-3: Verify Database Storage
- Ensure custom labels are being saved when user edits them in the fields editor
- Check if there's a column for storing custom labels in the settings field table
- Add column if it doesn't exist

## Non-Functional Requirements

### NFR-1: Backward Compatibility
- Existing exports without custom labels should continue to work
- NULL/empty labels should be handled gracefully

## Acceptance Criteria

- [ ] Located the settings export API endpoint
- [ ] Identified where custom field labels are stored in database
- [ ] Custom label appears in export JSON for the specified field
- [ ] Export includes custom labels for all fields that have them set

## Expected Behavior

When exporting settings for `PT_APPEAL_DEADLINES`, the field `APPEAL_SUBMISSION_DEADLINE_DAYS_AFTER_NOTICE` should include the custom label:

```json
{
  "FieldName": "APPEAL_SUBMISSION_DEADLINE_DAYS_AFTER_NOTICE",
  "DisplayName": "Appeal submission deadline days after notice",
  "DataType": "int",
  ...
}
```

## Known Challenges

- Need to find the settings export API (not found in initial search)
- May be in a different codebase or external service
- Need to understand the settings/dictionary data model

## Notes

User mentioned they "created an export of all settings" and noticed the custom labels are missing. They specifically set a label in "the fields editor" which suggests there's a UI for editing field metadata.
