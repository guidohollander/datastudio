# IMPORTANT: Restart Next.js Dev Server

## Changes Made
The following UI enhancements have been implemented:

### Configure Step
- **Table name** now displayed under each component header
- Format: `Table: CHANGES • 3 fields`

### Preview Step  
- **Table name** now displayed next to each component name
- Format: `changes (Table: changes)`

### Other Recent Changes
- ✅ Preview step shows FK fields as "will be generated"
- ✅ Modified fields highlighted with MODIFIED badge
- ✅ Next buttons at top of Review, Configure, and Preview steps
- ✅ Commit checkbox defaults to true
- ✅ Replay tab is default active tab

## How to See the Changes

### Step 1: Restart the Dev Server
```powershell
# Stop the current dev server (Ctrl+C in the terminal running npm run dev)
# Then restart it:
cd c:\dev\db\snapshot\ui\scenario-studio
npm run dev
```

### Step 2: Clear Browser Cache
1. Press `Ctrl+Shift+Delete`
2. Select "Cached images and files"
3. Click "Clear data"

OR

1. Open Developer Tools (F12)
2. Right-click the Refresh button
3. Select "Empty Cache and Hard Reload"

### Step 3: Reload the Application
1. Close all browser tabs for the application
2. Open a new tab
3. Navigate to `http://localhost:3000`
4. Go to Replay section
5. Load Contract
6. You should now see table names displayed

## What You Should See

### In Configure Step:
```
┌─────────────────────────────────────┐
│ changes                             │
│ Table: CHANGES • 3 fields           │
├─────────────────────────────────────┤
│ Field | Original | Preview | Gen... │
├─────────────────────────────────────┤
│ ...                                 │
└─────────────────────────────────────┘
```

### In Preview Step:
```
CHANGES (Table: changes)
┌──────────────────────────────────────┐
│ Field | Original | Generated | Gen...│
├──────────────────────────────────────┤
│ ...                                  │
└──────────────────────────────────────┘
```

## If Still Not Visible

If you still don't see the table names after restarting:

1. Check browser console (F12) for any JavaScript errors
2. Verify the dev server restarted successfully without errors
3. Try a hard refresh (Ctrl+F5)
4. Check if the file changes were saved correctly
