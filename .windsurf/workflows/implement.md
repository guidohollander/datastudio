---
description: Fully autonomous implementation workflow. Translate request, implement changes, run tests, fix errors automatically, and report final result.
---

# Structured Development Workflow

This is a **deterministic, self-correcting development workflow** that transforms informal feature requests into production-ready code. It loops continuously until the user is satisfied.

## How It Works

1. You write a request in `.windsurf/myway.txt` (informal language is fine)
2. Cascade formalizes it, implements it, validates it, and asks if you're satisfied
3. If not satisfied, you update `myway.txt` and **the entire cycle repeats from PHASE 1**
4. The loop continues until you answer "y" to the satisfaction gate

## Prerequisites

1. Feature request must be in `.windsurf/myway.txt`
2. Dev server should be running if UI changes are involved
3. Database should be accessible if backend changes are involved

---

## Workflow Steps

### PHASE 1: Request Formalization

Read the feature request from `.windsurf/myway.txt` and create a formal specification.

1. Read `.windsurf/myway.txt` to understand the informal request
2. Create or update `.windsurf/current-request.md` with:
   - Clear feature description
   - Functional requirements (FR-1, FR-2, etc.)
   - Non-functional requirements (performance, security)
   - Edge cases to handle
   - Acceptance criteria (how we know it's done)
   - Expected frontend behavior (if applicable)
   - Expected backend behavior (if applicable)
   - Known risks

**Example:**
```
myway.txt: "add user settings page"

becomes →

current-request.md:
- FR-1: Display user settings form
- FR-2: Allow editing email, name, password
- FR-3: Validate email format
- FR-4: Show success/error messages
- Edge case: Handle missing user data
- Acceptance criteria: Form saves correctly, validation works
```

---

### PHASE 1.5: Review and Proceed

**REVIEW GATE — User confirms formalized request**

// turbo
1. Run proceed script:
```bash
.windsurf\proceed.ps1
```

2. Script displays the formalized `current-request.md`

3. User reviews the requirements and decides:
   - **"y"** → Proceed to PHASE 2
   - **"n"** → User modifies `current-request.md`, run proceed.ps1 again

---

### PHASE 2: Test-First Design (Conditional)

**Determine if automated tests are applicable** by checking:
- Does the project have a `playwright.config.*` or `package.json` with a test script?
- Does the request involve UI interactions that can be browser-tested?
- Has the user explicitly said NOT to create tests?

**If tests are NOT applicable** (no test framework, user said no, or purely backend/SQL change):
- Skip this phase entirely, proceed to PHASE 3
- Note in `current-request.md`: "Tests skipped: [reason]"

**If tests ARE applicable:**
1. Create test file in `tests/workflow/[feature-name]-[YYYY-MM-DD].spec.ts`
2. Tests must:
   - Run in headed mode (visible browser)
   - Use stable selectors (`data-testid` attributes)
   - Assert UI state changes
   - Verify network requests (endpoint + status)
   - Fail on console errors
   - Fail on HTTP 4xx/5xx responses
   - Be re-runnable at any time

**Test template:**
```typescript
import { test, expect } from '@playwright/test'

test.describe('Feature Name', () => {
  test('should display feature page', async ({ page }) => {
    await page.goto('/feature-route')
    await expect(page.locator('[data-testid="main-element"]')).toBeVisible()
  })

  test('should perform main action', async ({ page }) => {
    await page.goto('/feature-route')
    await page.click('[data-testid="action-button"]')
    await page.waitForResponse(resp => 
      resp.url().includes('/api/endpoint') && resp.status() === 200
    )
    await expect(page.locator('[data-testid="result"]')).toBeVisible()
  })
})
```

---

### PHASE 3: Implementation

**IMPORTANT: Re-read `.windsurf/current-request.md` NOW before implementing anything.**
The user may have modified it during PHASE 1.5 review. Always implement based on the CURRENT file contents, not what you wrote earlier.

// turbo
1. Read `.windsurf/current-request.md` to get the final requirements
2. Make all necessary code and/or database changes based on the CURRENT `current-request.md`
3. Add `data-testid` attributes if tests were created
4. Ensure zero errors:
   - No console errors
   - No unhandled promise rejections
   - No server 500 responses

---

### PHASE 4: Automated Validation (Conditional)

**Only run this phase if tests were created in PHASE 2.**

If no tests were created, skip to PHASE 6.

// turbo
1. Run tests:
```bash
npm run test:workflow
```

2. **Monitor for errors — CRITICAL:**
   - Always check command exit codes (non-zero = failure)
   - Read error messages carefully
   - Fix errors immediately, re-run until exit code is 0
   - Do NOT proceed to PHASE 6 if any command failed

3. Check results:
   - ✅ All tests pass → Proceed to PHASE 6
   - ❌ Any test fails → Append failures to myway.txt, proceed to PHASE 5
   - ❌ Command error → Fix and retry

---

### PHASE 5: Error Translation Loop

**Only entered when tests fail.**

1. Analyze the failure:
   - Read error message
   - Check screenshots in `test-results/`
   - Review trace files if available

2. Determine root cause:
   - Missing functionality? Wrong selector? API error? Timing issue?

3. Update `.windsurf/current-request.md` with iteration findings:
```markdown
### Iteration Findings

#### Iteration 1 (YYYY-MM-DD)
**Failure:** Element not found
**Root Cause:** Missing data-testid attribute
**Fix Implemented:** Added data-testid to button
```

4. Fix the code
5. Re-run tests (go back to PHASE 4)
6. Repeat until all tests pass

---

### PHASE 6: Satisfaction Gate

**⚠️ MANDATORY — NEVER SKIP ⚠️**

Run after every implementation, regardless of whether tests were created or skipped.

// turbo
1. Run the **project-local** satisfaction script (NEVER use an absolute path from another project):
```bash
.windsurf\satisfied.ps1
```

2. Wait for user response — do NOT return control to chat until user responds.

3. **If YES:** Workflow complete for this request.

4. **If NO:**
   - Read the updated `.windsurf/myway.txt` for the new or refined request
   - **Restart the entire workflow from PHASE 1** with the new request
   - This loop continues until the user answers "y"

---

## Global Rules

- **Full loop on "n":** When satisfied.ps1 returns "n", ALWAYS restart from PHASE 1 — formalize the new request, run proceed.ps1, implement, validate, then run satisfied.ps1 again
- **Satisfaction gate is mandatory:** ALWAYS run `.windsurf\satisfied.ps1` at the end of EVERY cycle — NEVER skip, NEVER use a hardcoded absolute path
- **No premature completion:** Do NOT return control to chat until satisfied.ps1 has been executed and user has responded
- **Tests are conditional:** Determine per-request whether tests apply — don't hardcode "always" or "never"
- **Zero errors:** No silent failures, no 500 errors
- **Deterministic:** Same input = same output

---

## File Structure

```
[project-root]/
├── .windsurf/
│   ├── myway.txt                # Feature requests (informal, updated each cycle)
│   ├── current-request.md       # Formalized current request (reset each cycle)
│   ├── proceed.ps1              # Review gate script (PHASE 1.5)
│   ├── satisfied.ps1            # Satisfaction gate script (PHASE 6)
│   └── workflows/
│       └── implement.md         # This workflow (single source of truth)
└── [project source files]
```

---

## Example: Complete Run with Loop

**Cycle 1:**
- `myway.txt`: "VFK fields should show description instead of raw GUIDs"
- PHASE 1: Formalize → `current-request.md` with FR-1 through FR-4
- PHASE 1.5: `proceed.ps1` → user answers "y"
- PHASE 2: No test framework detected → skip
- PHASE 3: Fix SQL `IsDescriptionField`, update frontend lookup logic
- PHASE 4: Skipped (no tests)
- PHASE 6: `satisfied.ps1` → user answers "n", updates `myway.txt`

**Cycle 2 (loop restart from PHASE 1):**
- `myway.txt`: "Also fix the workflow to be generic"
- PHASE 1: Formalize new request → new `current-request.md`
- PHASE 1.5: `proceed.ps1` → user answers "y"
- PHASE 3: Update `implement.md`
- PHASE 6: `satisfied.ps1` → user answers "y" → **Complete!**

---

## Troubleshooting

**satisfied.ps1 not found:**
- Use the project-local relative path: `.windsurf\satisfied.ps1`
- Never use an absolute path from another project (e.g. `C:\dev\js\...\satisfied.ps1`)

**Tests are flaky:**
- Use stable selectors (`data-testid`)
- Add proper waits for elements and network requests

**Feature works but tests fail:**
- Tests define what "works" means — fix the code to make tests pass
