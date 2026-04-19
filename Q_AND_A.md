OK - starting to get into my questions.... thought about going full whiteboard and then got over it...
 
1 - this is very much focused on testing data migration, and building synthetic test data for migration - correct?
2 - the tool uses the version of the application for migration to build the data model to be tested and then to build the synthetic test data set that fits to that version of the application - correct?
3 - if 2 is how we should see it - then does this have to run on the clients environment or do we run it in the Blyce test environment for the the application?
 
 
4 - are we then able to use our own test environment to create the template for the clients migration and the synthetic test data on our own environment?
5 - if the tool is using the migration 'clicks' to define what from the data model needs to be tested, for a specific version of the application, does that allow for reuse of the generated test data across different versions of the application for different scenarios, or are we creating a one shot test data set for one specific scenario?
6 - if we are creating one shot test data sets, where do they land and how do we scrub them after use (they will sit there taking up space and confusing the issue otherwise)?
7 - if we are creating reusable sets, how are we managing and maintaining those sets (ok too early for this question but lets put it on the table to capture the requirements)?
8 - perhaps homing in on my key question - this feels very focused on the specific data migration scenario - not problem with that but does it have application beyond that scenario?
9 - After the discussion in Medellin, is this the action that was expected?
 
 
10 - have we had input and verification from all stakeholders? If this is specific to data migration perhaps that is only Guido and Maud, but if it is for broader application have we taken input from other resources?
 
 
11 - will we be able to add more variance in here, names are good, but we will need a range of variance for proper testing (birth dates etc) - no need to build that now, just to know if it is possible
 
12 - For names - I see we have taxpayer 1, 2, 3 etc - can we either turn that to a, b, c, or a random string generator? again, not to do it, to discuss it - I think people rarely have numbers in their names, random strings are more realistic.
 
I like that this takes into account the issues with BeInformed and how it handles data - I want to make sure we are also look at generic test data that can support other types of testing...
 

Below is how I’m reading your questions, plus concrete answers and the decision points you’ll want to nail down. I’ll stick to the assumptions implied by your list, and I’ll explicitly call out where the answer depends on an architectural choice.

1) Yes: primary focus = migration testing + synthetic data for migration

Correct. What you describe is essentially a migration test-data factory:

Derive a target data model (as the application expects it).

Generate synthetic source + target-aligned datasets that are valid for that model.

Execute migration paths and validate outcomes (including Be Informed quirks: validations, constraints, record lifecycles, reference resolution, etc.).

It can be extended to other testing, but the “clicks → what to cover” approach screams “migration scenario capture”.

2) Yes: version-specific model derivation is the right way to see it

Correct. If the tool uses “the version of the application for migration” to infer/construct the model and constraints, then it is version-coupled by design.

That coupling is actually a feature for migration work because:

migrations are sensitive to schema + rules + reference lists + behaviors

Be Informed behavior can change between versions/configs

3) Does it have to run on the client environment?

Not necessarily. There are three workable modes; which one is “right” depends on what the tool needs access to.

Mode A — Blyce-only (preferred if feasible)

Run it in Blyce test environment with the same application version/config as the client.

✅ Best for speed, repeatability, IP control, less client friction

⚠️ Requires you to faithfully replicate: version + config + reference data + rules

Mode B — Client environment (required if tool needs client-only facts)

Run it on client infra when it depends on:

client-specific configuration / reference sets you cannot export

client-only integrations / identity / environments

regulatory restrictions (data locality, security)

Mode C — Hybrid (common in practice)

Model + generation in Blyce

Final validation run (or “calibration”) in client env

Key discriminator: Does model derivation require runtime access to the actual deployed application instance + its configuration?
If yes → client/hybrid. If no → Blyce-only is viable.

4) Can we build templates + synthetic sets in our own environment?

Yes, if you can replicate the client’s target constraints sufficiently.

In practice you’ll need a “migration test harness package” per client that pins:

application version

configuration export/import

reference lists (code tables / enumerations / master data baselines)

any derived constraints (validation rules, mandatory fields, uniqueness rules)

If you can package/import those, you can generate in Blyce reliably.

5) Reuse across versions vs one-shot for one version/scenario

This hinges on what “migration clicks” really represent:

If clicks define a scenario-specific pathway

Example: “Migrate Individual taxpayer with these subflows enabled.”

Then data sets are scenario-bound and often version-bound.

Reuse possible only with compatibility checks and transformations.

If clicks define a coverage model

Example: “These entities/relations/fields must be exercised.”

Then you can build reusable generators and emit datasets per version.

Best mental model:

Don’t try to reuse the dataset across versions.

Reuse the generator recipe (“intent + coverage + distributions + constraints”) and re-render the dataset for the version.

That gives you reuse without schema drift pain.

6) If one-shot sets: where do they land, and how to scrub?

You’re right to worry: “one-shot” datasets become landfill fast.

A clean approach is to treat every generated dataset as an ephemeral artifact with lifecycle metadata:

Where they land (recommendation):

A dedicated “test-data store” (could be DB, files, object storage) under a single namespace:

client / appVersion / scenario / runId

How to scrub (minimum viable governance):

Every dataset carries:

runId, createdAt, expiresAt, owner, scenario, version, hash/signature

Automated cleanup:

TTL-based purge job (e.g., delete after 30/60/90 days unless pinned)

“Pinning” mechanism:

promote a dataset to “baseline” only when explicitly approved

This avoids confusion and keeps storage predictable.

7) If reusable sets: how to manage and maintain them?

Even if it’s “too early”, your requirement is valid. Managing reusable sets means you’re doing test data product management:

Minimum structure that scales:

Catalog of datasets (or recipes) with:

supported versions / constraints

purpose tags (migration smoke, regression, edge cases, performance)

coverage statement (“exercises X/Y/Z”)

generation recipe versioning (semver)

Compatibility rules:

“dataset recipe v3 supports app versions 24.2–24.4”

Promotion flow:

draft → validated → baseline → deprecated

My strong recommendation: store and version “recipes”, not raw datasets, and regenerate per version/run.

8) Beyond migration: does this apply elsewhere?

Yes, but only if you decouple it from “migration clicks”.

If the engine can:

infer/consume a data model + constraints

generate valid synthetic entities with controlled variance

produce relationship-consistent datasets

…then it can support:

functional test data for new features

regression suites

performance/load test data

demo data

security/privacy-safe “realistic” datasets

But: if the only way to define coverage is via migration click-flows, then it will remain migration-centric.

So the key design question:
Can we define coverage via a generic “test intent spec” (entities, relations, distributions, edge cases) in addition to migration clicks?

9) After Medellín: is this the expected action?

Based on your framing: yes, if the Medellín outcome was “make migration testing repeatable and safe using synthetic data aligned to BI behavior.”

If the Medellín outcome was broader (“generic test data platform”), then this is a subset and you’ll want to explicitly position it as:

Phase 1: Migration test-data automation

Phase 2: General-purpose test data generation & governance

10) Stakeholder input/verification

Your instinct is right: scope determines stakeholders.

If migration-only:

Core stakeholders:

Guido (migration/testing strategy)

Maud (delivery/quality/approach)
Plus usually:

whoever owns BI configuration/versioning

whoever owns client delivery constraints (security/legal)

If broader testing platform:

Add:

product/architecture owner

QA/test lead(s)

performance testing stakeholders

security/privacy/GDPR representative

platform/DevOps (where it runs, how it’s operated)

A practical way to force clarity: write a 1-page scope statement with:

“In scope now” (migration)

“Explicitly out of scope now”

“Later candidates”

11) Variance (birth dates, distributions, edge cases)

Yes, it should be possible, but only if the generator is built around:

distributions (uniform/normal/custom)

constraint-aware generation (age ranges, date dependencies)

edge-case injection (nulls, extremes, invalid-but-accepted patterns, etc.)

Even if you don’t build it now, ensure the design allows:

per-field variance policies

per-entity scenario overrides

“seeded randomness” for reproducibility

12) Names like “taxpayer 1/2/3” → use realistic patterns

Agree. Two improvements that don’t create complexity:

Alphabetic suffix (A/B/C) is slightly better but still artificial.

Best is seeded pseudo-random realistic strings:

e.g., “Jansen”, “De Vries”, etc. (if allowed)

or pronounceable randoms (“Marven”, “Kaldor”) if you want to avoid real-name lists

Important constraints:

Reproducibility: same seed → same outputs

Uniqueness: avoid collisions where uniqueness is required

Cultural fit: optional locale profiles (NL, EN, etc.)

Your implied “core requirements” (what I’d capture)

From your questions, these are the non-negotiables that matter:

Version-aware model + rules alignment (BI realities included)

Environment strategy (Blyce vs client vs hybrid) with clear decision criteria

Reuse via recipes (preferred) rather than raw dataset reuse

Lifecycle governance (TTL cleanup, cataloging, pin/promote)

Variance support as a first-class capability (seeded randomness, distributions, edge-case injection)

Scope clarity: migration-first but extensible to generic testing

If you want, paste whatever you have as the current “tool description” (even rough bullets), and I’ll rewrite it into a crisp scope + operating model that answers questions 1–12 in a way you can re-use with Maud/others (and that makes the environment decision explicit).

Process the following in the answerring of the questions

the framework addresses two issues, synthetic data generation in the first place and data migration in the second place. The contract that is derived from the capture serves as a contract for synthetic data generation (with variables and distribution), so for internal use and for our clients for data migration from their old systems.

For the internal use this should be Combined with existing automated test scripts from the test team, scenario's can be captured based on automated scenarios whenever needed and then, using the expression editor transformed into much larger, distributed sets. The role of test automation is vital. It is virtually impossible to make testset from today futureproof for tomorrow. It has to be recaptured and replayed whenever there's a need to.

Therefore, the stakeholders are more diverse than only the data migration team. Many more stakeholders can be defined: test teams when it comes to for example performance testing with large data sets, application designers / architects (does the functionality as is hold when used with large datasets. 

I'm aware that the current setup is not a panacea. It cannot serve all purposes, however it exceeds to only data migration.

Chatgpt, fill in where necessary. I will add more comments later and I want to add screenshots too. It sounds like the person who asks the questions does not fully understand the approach, especially in the area of the expressions

What needs attention in the current setup is the distribution

Got it. Below is a revised, filled-in answer set to your original 1–12 questions, now explicitly reflecting:

Primary problem #1 = synthetic data generation

Primary problem #2 = data migration (client-facing use case)

Capture output = a contract for generation (incl. variables + distributions)

Test automation is central: scenarios are re-captured/replayed; datasets are not “futureproof”

Stakeholders are broader than the migration team

Current weakness that needs attention: distribution

1 — Is this very much focused on testing data migration and building synthetic test data for migration?

**Partly, but it's broader.**

The framework addresses two primary use cases:

**Synthetic data generation (primary)**: Generate realistic, constraint-valid datasets from captured production patterns. The system captures a single real scenario (e.g., one taxpayer case) and can replay it 1 to 1000+ times with controlled variation.

**Data migration testing (secondary)**: Use the same contract to validate client migrations from legacy systems. The contract serves as both a specification and a validation tool.

**Additional use cases already supported:**
- Performance testing with large datasets (generate hundreds/thousands of records from one capture)
- Regression testing with production-realistic data patterns
- Load testing and scalability validation
- Integration testing with consistent, reproducible datasets

The key insight: migration is an important use case, but the framework is fundamentally a **production-pattern learning and replay system** that applies to any scenario where you need realistic test data at scale.

2 — Does it use the application version to build the model and then the synthetic dataset that fits that version?

**Yes - the contract is version-aware by design.**

**How it works:**
1. **Capture phase**: The system monitors database activity during a defined time window (e.g., while you create one taxpayer case)
2. **Contract generation**: Automatically analyzes captured data to build a hierarchical contract showing:
   - All components (tables) involved (e.g., 13 components for a typical case)
   - All fields captured (e.g., 123 fields)
   - Parent-child relationships (automatic FK detection)
   - Field types, cardinality (min/max occurs), and required/optional status
3. **Version coupling**: The contract is implicitly version-aware because it reflects the actual schema and constraints of the database at capture time

**The contract then serves as:**
- A specification for what data is needed
- A template for replay with generator expressions
- Documentation for migration teams
- A validation tool (Sample JSON and JSON Schema outputs)

**Current implementation:** Contract generation is fully automated via `dbo.GenerateContractFromCapture` stored procedure. No manual schema definition required.

3 — Does this have to run on the client environment, or can we run it in Blyce test?

**Current architecture: SQL Server + Next.js web UI - runs wherever you have database access.**

**Technical requirements:**
- SQL Server database (localhost:1433 in current setup)
- Database with BeInformed application schema
- Next.js web UI (Node.js)
- Network access to SQL Server

**Deployment options:**

**Option A — Blyce environment (recommended for internal testing)**
- Run against Blyce test database with application version/config
- Full control, repeatability, no client friction
- Can generate large datasets without impacting client systems
- Requires replicating client's version/config/reference data

**Option B — Client environment (for migration validation)**
- Deploy to client infrastructure when needed for:
  - Client-specific configurations you cannot export
  - Regulatory/data locality requirements
  - Final migration acceptance testing

**Option C — Hybrid (common practice)**
- Capture + contract generation in Blyce
- Large-scale generation in Blyce
- Final validation/calibration in client environment

**Current implementation:** The framework is database-agnostic in terms of location - it works wherever SQL Server is accessible. The web UI connects via connection string configuration.

4 — Can we use our own test environment to create the template for a client migration and generate synthetic data there?

**Yes - this is the recommended approach.**

**Current workflow:**
1. **In Blyce test environment:**
   - Set up application version matching client target
   - Run automated test scenario or manual clicks to create one complete case
   - Click "Start Capture" → perform actions → "End Capture"
   - System automatically generates contract from captured data

2. **Contract customization (optional):**
   - View contract documentation (hierarchical component/field view)
   - Customize if needed (exclude components/fields, reorder, adjust cardinality)
   - Add generator expressions in Notes column for fields that need variation

3. **Replay at scale:**
   - Generate 1 to 1000+ records from the single captured scenario
   - System maintains all FK relationships and referential integrity
   - Framework tables (CHANGES, MUTATION) replayed in exact order

**Key principle:** Don't treat datasets as static artifacts. Instead:
- Maintain automated scenarios (test scripts)
- Recapture when application changes
- Replay with current generator expressions
- This keeps test data aligned with current application version

**Current storage:** All captures stored in `MigrationScenarioRun` and `MigrationScenarioRow` tables with full metadata (runId, timestamps, status, JSON payloads).

5 — Are we creating one-shot datasets, or reusable across versions/scenarios?

**Reuse happens at the recipe level, not the dataset level.**

**What IS reusable:**
- **Automated scenario scripts** (test team maintains these)
- **Capture approach** (same clicks/workflow for a scenario type)
- **Generator expressions** (stored in MigrationDomainField.Notes column)
- **Contract structure** (component/field hierarchy)
- **Replay configuration** (number of records, customizations)

**What is NOT reusable across versions:**
- Raw generated datasets (schema may change)
- Specific IDENTITY values (framework tables)
- Hardcoded FK references

**Key principle:** "A test set made today is not futureproof for tomorrow."

**Therefore, the workflow is:**
1. Maintain automated scenarios (or documented manual workflows)
2. When application version changes → recapture the scenario
3. Review/update generator expressions if needed
4. Replay to generate fresh dataset for new version

**Current implementation:**
- Each capture creates a new `MigrationScenarioRun` with unique RunId (GUID)
- Runs are listed in the UI with status (capturing/done/replaying)
- You can replay any historical run, but best practice is to recapture for version changes
- Generator expressions are stored per field and can be copied/adapted across runs

6 — If one-shot sets exist, where do they land and how do we scrub them?

**Current implementation: Data lands in the actual application tables.**

**Where replayed data goes:**
- Replay inserts directly into business tables (SC_*, etc.)
- Framework tables (CHANGES, MUTATION, CMF*) also populated
- All data is "real" in the database - indistinguishable from manually created data

**Current cleanup approach:**
- **Manual**: Database administrator resets test database as needed
- **Metadata tracking**: All replays tracked in `MigrationScenarioRun` table with:
  - RunId (GUID)
  - ScenarioName
  - StartedAt / EndedAt timestamps
  - Status (capturing/done/replaying/error)
  - RecordCount

**What needs attention (future enhancement):**
- **Automated cleanup**: TTL-based purge jobs
- **Tagging**: Mark replayed records for easy identification/deletion
- **Isolation**: Option to replay into separate schema/database
- **Pinning**: Ability to mark certain datasets as "baseline" to preserve

**Current workaround:**
- Use database snapshots/backups before large replays
- Restore to clean state when needed
- Or maintain separate test databases per scenario type

7 — If we do maintain reusable sets, how do we manage them?

We manage “reusable recipes,” not static sets.
In practice, that means:
- **Versioned contracts**
- **Versioned expressions/distributions**
- **Linkage to the automated scenario(s) that produced the capture**
- **Promotion flow (draft → validated → baseline → deprecated)**
- **Recapture triggers when the app changes materially**

So yes: dataset governance is still a requirement, but the unit of reuse is the regeneratable specification.

8 — Does it have application beyond migration?

Yes, explicitly. This is one of the main internal value propositions:

combine with existing automated test scripts

capture scenarios from automation whenever needed

use expression editor to scale to large distributed sets

support:

regression testing with realistic data

performance testing (large datasets)

scalability validation (architects/designers asking “does this hold at scale?”)

robustness testing with variance/edge cases

It’s not a panacea; it won’t solve every test-data need. But it is clearly broader than migration.

9 — After Medellín, is this the action that was expected?

Yes, if the Medellín expectation was “make test data generation and replay systematic, tied to automation, and usable for migration and broader testing.”

The key alignment point you should state explicitly:

Medellín outcome = stop treating test data as handcrafted one-offs; instead use capture → contract → generate → replay with automation at the center.

10 — Stakeholder input/verification: is it only Guido/Maud?

No—stakeholders are broader by definition.

Minimum stakeholder set now includes:

Test automation team (source scenarios + regression harness)

Performance testing stakeholders (large dataset needs, workloads)

Application designers/architects (scale behavior, integrity under load)

Data migration team (client migration applicability)

DevOps/Platform (where it runs, storage, purge, environments)

Security/GDPR (synthetic guarantees, handling, client constraints)

So: you should not position this as “only migration stakeholders.”

11 — Will we be able to add more variance (birth dates, etc.)?

**Current capabilities: YES - generator expressions support variance.**

**Currently implemented generator types:**
- `gen:ctx(fieldName)` - Use value from another field in the hierarchy
- `gen:seq()` - Sequential numbering (with optional prefix/suffix like "TP-{seq}-2024")
- `gen:literal(value)` - Static value
- `gen:concat(...)` - Combine multiple generators (supports ctx, seq, literal, and string literals)
- `gen:random(min,max)` - Random numbers (for numeric fields)
- `gen:pick(val1,val2,val3)` - Random selection from list
- `gen:pool(val1,val2,val3)` - Cycle through values

**Parser implementation:**
- Inline SQL parsing in `dbo.ReplayDomainFast` stored procedure
- No external dependencies - all generation happens in SQL Server
- Supports nested expressions: `gen:concat(ctx(surname), ', ', ctx(firstNames))`

**What works today:**
- Name variation via ctx() references
- Sequential IDs with prefixes
- Random numeric values
- Combining fields into calculated values (like fileName)

**What needs attention (as you noted):**
- **Date distributions** (birth dates with realistic ranges)
- **Correlated values** (age ↔ taxpayer type consistency)
- **Statistical distributions** (normal, uniform, custom)
- **Edge case injection** (nulls, boundary values, invalid-but-accepted)
- **Locale-aware generation** (Dutch names, addresses, etc.)
- **Seeded randomness** (reproducible "random" values)

The architecture supports adding these - the parser is extensible. Distribution design is the next logical enhancement.

12 — "taxpayer 1/2/3": can we do a/b/c or random strings?

**Yes - this is exactly what generator expressions solve.**

**Current approach (example from actual implementation):**
```sql
-- Instead of hardcoded "taxpayer 1, taxpayer 2, taxpayer 3"
-- Use generator expressions:

surname: gen:pool(Jansen,De Vries,Bakker,Visser,Smit)
firstNames: gen:pool(Jan,Pieter,Anna,Maria,Hendrik)
fileName: gen:concat(ctx(surname), ', ', ctx(firstNames))
```

**Result:** Each replayed record gets a different combination:
- Record 1: "Jansen, Jan"
- Record 2: "De Vries, Pieter"
- Record 3: "Bakker, Anna"
- etc.

**For sequential variation:**
```sql
fileName: gen:concat('Taxpayer-', seq(), '-', ctx(surname))
```
Result: "Taxpayer-1-Jansen", "Taxpayer-2-DeVries", etc.

**Key point the questioner may be missing:**
- **The capture** records ONE real example (e.g., "John Smith")
- **The contract** defines the structure (surname field, firstNames field, fileName field)
- **The expressions** define how to vary those values during replay
- **The replay** generates 1 to 1000+ records with different values

**Current limitation:**
- No built-in name libraries (you manually specify pool values)
- No locale-aware random name generation
- No uniqueness enforcement (could generate duplicates if pool is small)

**Future enhancement:**
- Locale-aware name generators: `gen:name(locale=NL,type=surname)`
- Uniqueness constraints: `gen:unique(pool(...))`
- Realistic random strings: `gen:pronounceable(length=8)`

What clearly needs attention in the current setup

You already pointed to it, and I agree: distribution.

a distribution strategy per field type (dates, amounts, categorical codes)

correlation rules (e.g., age ↔ taxpayer type, property ↔ valuation ranges)

“scale profiles” (small/medium/large) tied to performance testing targets

a repeatable “recapture + replay” workflow integrated with automated tests

One sentence you can use to correct the misunderstanding

“The capture does not aim to create a futureproof dataset; it produces a contract that, combined with test automation and expressions/distributions, lets us regenerate fit-for-purpose datasets whenever the application/version/scenario changes.”

If you add screenshots later, the main thing I’ll look for is: what exactly the expression editor can express today (distributions, joins/correlations, uniqueness rules, reference sets). That will determine how strong we can claim the variance story is, and what gaps remain.

---

## SUMMARY: What's Actually Built vs What Needs Enhancement

### ✅ **Currently Implemented and Working**

**Core Framework:**
- Snapshot-based capture system (SHA-256 hashing for change detection)
- Automatic contract generation from captured data (13 components, 123 fields in current example)
- Hierarchical component/field relationships with FK detection
- Full replay engine with referential integrity maintenance
- BeInformed framework table handling (CHANGES, MUTATION, CMF* in exact order)
- Primary key remapping across all related tables

**Generator Expression System:**
- Inline SQL parser in `dbo.ReplayDomainFast`
- Supported expressions: `ctx()`, `seq()`, `literal()`, `concat()`, `random()`, `pick()`, `pool()`
- Nested expression support: `gen:concat(ctx(surname), ', ', ctx(firstNames))`
- No external dependencies - pure SQL Server implementation

**User Interface:**
- Next.js 16 web application with modern React components
- Contract documentation page with hierarchical expand/collapse
- Customization interface (exclude components/fields, reorder, adjust cardinality)
- Replay wizard with record count selection (1-1000+)
- Real-time progress monitoring during replay
- Sample JSON and JSON Schema generation

**Data Management:**
- All captures stored in `MigrationScenarioRun` and `MigrationScenarioRow` tables
- Full metadata tracking (runId, timestamps, status, JSON payloads)
- Runs listed in UI with filtering and status indicators

### ⚠️ **What Needs Attention (Acknowledged Gaps)**

**Distribution & Variance:**
- Date distributions (birth dates with realistic ranges)
- Correlated values (age ↔ taxpayer type consistency)
- Statistical distributions (normal, uniform, custom)
- Edge case injection (nulls, boundary values)
- Locale-aware generation (Dutch names, addresses)
- Seeded randomness for reproducibility

**Data Lifecycle:**
- Automated cleanup (TTL-based purge)
- Tagging replayed records for identification/deletion
- Isolation options (separate schema/database)
- Pinning mechanism for baseline datasets

**Generator Enhancements:**
- Built-in name/address libraries
- Uniqueness enforcement
- Locale-specific generators
- More sophisticated random string generation

### 🎯 **Key Principle to Communicate**

**"The capture does not aim to create a futureproof dataset; it produces a contract that, combined with test automation and expressions/distributions, lets us regenerate fit-for-purpose datasets whenever the application/version/scenario changes."**

### 📊 **What the Expression Editor Can Express Today**

**Fully Supported:**
- Cross-component field references: `gen:ctx(surname)`
- Sequential numbering with formatting: `gen:concat('TP-', seq(), '-2024')`
- Static values: `gen:literal(0)`
- Random numeric ranges: `gen:random(18,65)`
- Value pools (cycling): `gen:pool(Value1,Value2,Value3)`
- Random picks: `gen:pick(Option1,Option2,Option3)`
- Complex combinations: `gen:concat(ctx(surname), ', ', ctx(firstNames))`

**Not Yet Supported:**
- Statistical distributions (normal, weighted)
- Correlation rules between fields
- Uniqueness constraints
- Date range generators with realistic distributions
- Locale-aware data generation
- Reference set lookups from database tables

### 🔄 **Recommended Workflow (Based on Actual Implementation)**

1. **Capture**: Run one complete scenario (automated or manual) with capture enabled
2. **Review**: Check generated contract in UI - verify all 13 components and 123 fields captured
3. **Customize**: Add generator expressions in Notes column for fields needing variation
4. **Preview**: Use preview mode to verify generated data looks correct
5. **Replay**: Generate 1-1000+ records with "Start Replay" button
6. **Monitor**: Watch real-time progress indicator
7. **Validate**: Check replayed data in application
8. **Recapture**: When application version changes, recapture and replay with updated expressions

### 🎓 **For Stakeholder Communication**

**Test Automation Team:** Framework integrates with your automated scenarios - capture once, replay many times with variation

**Performance Testing:** Generate thousands of records from single capture - maintains all FK relationships and BeInformed framework requirements

**Migration Team:** Contract serves as both specification and validation tool for client migrations

**Architects/Designers:** Test scalability with realistic data patterns - does functionality hold at 1000+ records?

**DevOps/Platform:** SQL Server + Next.js stack, runs wherever you have database access, metadata tracking for all operations

---

**Screenshots to add:** Contract documentation page, customization interface, generator expression examples, replay progress, Sample JSON output