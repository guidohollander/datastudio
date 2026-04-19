# Live Preview Implementation Summary

## What Was Implemented

### 1. API Endpoint for Generator Evaluation
Created: `c:\dev\db\snapshot\ui\scenario-studio\app\api\generator\evaluate\route.ts`

This endpoint:
- Accepts a generator expression (e.g., `pool(firstNames.male)`)
- Calls `dbo.EvaluateGeneratorExpression` stored procedure
- Returns the generated value

### 2. UI Changes in Configure Step
Modified: `c:\dev\db\snapshot\ui\scenario-studio\src\components\replay\ReplayWizard.tsx`

**Added:**
- `previewValues` state to store generated preview values
- `generatePreviewValue()` function to call the API
- `onBlur` handler on generator input fields

**How It Works:**
1. User types a generator expression (e.g., `pool(surnames.dutch)`)
2. When user leaves the field (blur event), the system:
   - Calls `/api/generator/evaluate` with the expression
   - Stores the result in `previewValues` state
   - Updates the Preview Value column with the generated example

**Color Coding:**
- **Blue**: Fields using `ctx()` - shows original captured value
- **Green**: Fields with generators - shows live-generated example value
- **Gray**: FK/relationship fields - shows "will be generated"
- **Black**: Fields without generators - shows original value

## How to Test

### Step 1: Restart Next.js Dev Server
```powershell
cd c:\dev\db\snapshot\ui\scenario-studio
npm run dev
```

### Step 2: Navigate to Replay Wizard
1. Go to the Scenarios page
2. Select your captured scenario
3. Click "Replay"

### Step 3: Test Live Preview in Configure Step
1. In the Configure step, find a field like `FIRSTNAMES`
2. Type a generator expression: `pool(firstNames.male)`
3. **Press Tab or click outside the field** (this triggers onBlur)
4. Watch the "Preview Value" column update with a generated example like "John" or "Michael"

### Step 4: Try Different Generators
- `pool(surnames.dutch)` → Shows "van der Berg", "Jansen", etc.
- `random(1000, 9999)` → Shows "5432", "8901", etc.
- `literal(TestValue)` → Shows "TestValue"
- `ctx(firstnames)` → Shows original captured value (blue)

### Step 5: Verify in Preview Step
1. Click "Next: Preview"
2. The system auto-saves all generator changes
3. Preview shows actual generated values for all 5 items

## Technical Details

### API Request Format
```json
{
  "expression": "pool(firstNames.male)",
  "itemIndex": 1,
  "contextJson": "{\"firstnames\": \"Juan\"}"
}
```

### API Response Format
```json
{
  "result": "Michael"
}
```

### Error Handling
- If generator expression is invalid, preview shows "..."
- If API call fails, preview remains as "..."
- ctx() expressions don't trigger API calls (show original value directly)

## All Recent Fixes Applied

1. ✅ Fixed CASEID remapping (removed from CHANGES/MUTATION contracts)
2. ✅ Fixed status fields (HOMEADDRESSSTATUS uses literal(Active))
3. ✅ Added comparison view to Configure and Preview steps
4. ✅ Removed table exclusions (CMF%, SC_USERASSIGNMENT, SC_WORKITEM now included)
5. ✅ Made FK fields readonly with "Determined by relation generator"
6. ✅ Auto-save generators before preview
7. ✅ Live preview generation on blur
8. ✅ Deleted all bad replayed data with broken FK relationships

## Next Steps

After restarting the dev server:
1. Test the live preview functionality
2. Delete any remaining bad replayed data if needed
3. Replay with the fixed contract
4. Verify CHANGES/MUTATION records link correctly to replayed individuals
