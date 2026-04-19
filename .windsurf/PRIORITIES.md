# Synthetic Test Data Generation: Priorities

## Next Steps (In Order)

### 1. Performance Benchmarking
**What:** Test if the system can generate large datasets fast enough for real use.  
**Effort:** 1-2 weeks  
**Why:** If it's too slow, the whole approach won't scale. This is a go/no-go decision.

### 2. Application Validation Strategy
**What:** Figure out how to validate that generated data actually works in the application.  
**Effort:** 2-3 weeks  
**Why:** Database-level generation might create data that breaks application business rules. Need to know the failure rate.

### 3. Reference Data Discovery
**What:** Build a way to automatically detect and reuse reference values (countries, taxpayer types, etc.).  
**Effort:** 2-3 weeks  
**Why:** Manual configuration of reference data doesn't scale. Need automated discovery.

### 4. Expression Library
**What:** Create a library of reusable generator expressions so common patterns don't need to be recreated.  
**Effort:** 2-3 weeks  
**Why:** Saves time and ensures consistency across scenarios.

### 5. Data Lifecycle Management
**What:** Implement tagging and cleanup for generated datasets.  
**Effort:** 2-3 weeks  
**Why:** Generated data will pile up and clutter test databases without proper lifecycle management.

### 6. Stakeholder Engagement
**What:** Present to QA leads, dev leads, deployment team, and product/architecture.  
**Effort:** 2-4 weeks (ongoing)  
**Why:** Need broader input to understand real requirements and validate that this solves actual problems.

### 7. Scenario Modularization (Experimental)
**What:** Investigate if scenarios can be broken into reusable modules.  
**Effort:** 2-3 weeks  
**Why:** Would enable scenario linking (10K individuals, 60% with obligations). But might not be feasible.

### 8. Frontend Improvements
**What:** Better expression editor, distribution UI, reference data browser.  
**Effort:** 3-4 weeks  
**Why:** Makes the tool usable for non-technical stakeholders. Can wait until validation is done.

---

## Decision Point (After Items 1-3)

If performance, validation, and reference data all work → continue to advanced features.  
If any of these fail → adjust scope or reconsider the approach.

---

## Not Urgent (Can Wait)

- Advanced distributions (correlated values, statistical distributions)
- Generic Settings Framework integration
- Test automation integration
- Multi-tenant and self-service

These are Phase 3 items. Only pursue if Phase 2 validation succeeds.
