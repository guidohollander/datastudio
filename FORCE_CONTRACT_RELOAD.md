# Force Contract Reload Instructions

## The Problem
You're seeing old generator expressions (like `pool(countries.iso)`, `random(1, 999)`) even after the database has been fixed. This is because:

1. The UI cached the old contract data
2. Your browser may have cached the API responses
3. The React state is holding onto old values

## Solution: Force a Complete Reload

### Step 1: Clear Browser Cache
1. Open Developer Tools (F12)
2. Right-click the Refresh button
3. Select "Empty Cache and Hard Reload"

OR

1. Press Ctrl+Shift+Delete
2. Clear "Cached images and files"
3. Click "Clear data"

### Step 2: Restart Next.js Dev Server
```powershell
# Stop the current dev server (Ctrl+C)
cd c:\dev\db\snapshot\ui\scenario-studio
npm run dev
```

### Step 3: Reload the Page Completely
1. Close all browser tabs for the application
2. Open a new tab
3. Navigate to http://localhost:3000
4. Go to the Replay section
5. Click "Load Contract" button

### Step 4: Verify the Fix
After reloading, you should see:
- **108 fields** with `ctx()` generators (preserving original values)
- **4 fields** with NULL generators (FK fields for auto-remapping)
- **0 fields** with `pool()`, `random()`, `literal()`, or other generators

### What Should Happen
- All non-FK fields should show `ctx(fieldname)` in the Generator column
- No fields should be marked as MODIFIED (yellow background)
- Original values should equal Generated values (green background)
- Only FK fields should show "will be generated" (amber background)

## If Still Not Working

Delete the scenario and create a new one:
1. Go to Scenarios page
2. Delete the current scenario
3. Create a new scenario
4. Start a new capture
5. End capture
6. Go to Replay
7. Load Contract

The contract will be generated fresh from the database with all the fixes applied.

## Database Verification

To verify the database has the correct generators:

```sql
-- Should return 108 rows (all with ctx())
SELECT COUNT(*) 
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.Notes LIKE '%ctx(%';

-- Should return 4 rows (FK fields with NULL)
SELECT COUNT(*) 
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.Notes IS NULL;

-- Should return 0 rows (no pool/random/literal generators)
SELECT COUNT(*) 
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE c.ObjectKey = 'captured_data'
  AND f.Notes LIKE 'gen:%'
  AND f.Notes NOT LIKE '%ctx(%';
```

All three queries have been verified and are correct in the database.
