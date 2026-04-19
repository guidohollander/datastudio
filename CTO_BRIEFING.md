# Synthetic Test Data Generation: CTO Briefing

## Executive Summary

We've built a tool that learns from production data patterns and regenerates realistic test datasets at scale, eliminating weeks of manual test data creation while enabling performance testing and migration validation that was previously impossible. Migration is the first use case, not the only one.

---

**Question:** "This is very much focused on testing data migration, and building synthetic test data for migration - correct?"

**Answer:**

The synthetic test data generation tool solves the enterprise test data problem across multiple domains. It captures real production scenarios that are already created and maintained as automated test cases and replays them 1 to 1000+ times with controlled variation.

**[PROCESS FLOW IMAGE PLACEHOLDER]**

*The workflow: Automated tests → Capture database impact → Generate contract definition → Contract-based transformation → Specify distribution → Replay at scale. This process ensures test data generation is systematic and tied to existing test automation, not manual handcrafted artifacts.*

**Primary applications:**
- **Performance testing**: Generate realistic datasets at scale (previously impossible without weeks of manual work)
- **Migration validation**: Test client migrations with production-equivalent patterns
- **Regression testing**: Maintain test data that evolves with application changes
- **Scalability validation**: Test architectural assumptions with realistic data volumes
- **Integration testing**: Consistent, reproducible datasets across test cycles

**Business impact:**
- Test data creation: weeks → hours
- Performance testing: now feasible with realistic data at scale
- Migration risk: measurably reduced through production-pattern validation
- Continuous testing: data stays aligned as applications evolve

Migration is a valuable use case that proves the approach, but the tool serves any scenario requiring realistic test data at scale.

---

**Question:** "The tool uses the version of the application for migration to build the data model to be tested and then to build the synthetic test data set that fits to that version of the application - correct?"

**Answer:**

The synthetic test data generation tool is version-aware by design. Each capture reflects the current application state—schema, constraints, and business rules—creating a contract that documents what that version requires.

Here's the important bit: **datasets themselves are not future-proof**. Existing data in a given location will be upgraded or updated using existing migration scripts (as part of regular update scripts delivered by project teams), but new datasets that are built from scratch should stem from automated tests, capture, contract-based transformation, distribution specification, and replay.

When applications evolve, you recapture the scenario (minutes, not weeks), generator expressions adapt to the new schema automatically, and you regenerate datasets aligned with the current version. Traditional test data scripts break with every schema change, requiring manual maintenance. This tool maintains the ability to regenerate fit-for-purpose datasets on demand, not static datasets that become technical debt.

---

**Question:** "If 2 is how we should see it - then does this have to run on the clients environment or do we run it in the Blyce test environment for the application?"

**Answer:**

There are two distinct purposes here, and that determines where it runs:

**Purpose 1: Internal synthetic test data generation**
Runs in Blyce test environments. We capture and generate datasets internally with full control, faster iteration, and no client dependencies. This supports performance testing, regression testing, scalability validation—all the internal testing needs.

**Purpose 2: External data migration purposes**
Runs at the client. When we're helping clients migrate from their old systems, the tool runs in their environment to generate or validate migration datasets according to the contract.

The tool itself runs wherever SQL Server is accessible—it's an architectural choice, not a technical constraint. For internal use, we deliver contracts and datasets to clients, not the tool itself. This reduces client friction and security concerns. For migration projects, we deploy where needed based on client-specific configurations, regulatory requirements, or data locality constraints.

---

**Question:** "Are we then able to use our own test environment to create the template for the clients migration and the synthetic test data on our own environment?"

**Answer:**

Yes, and that's actually the main purpose—capturing reusable contracts.

The synthetic test data generation tool is designed for internal development of these contracts. We capture production-equivalent scenarios in Blyce test environments, store generator expressions and contracts (not static datasets), recapture when client requirements or versions change, and generate 1 to 1000+ records on demand.

The value here is clear: build once, adapt for multiple clients through recapture. Test team maintains automated scenarios which automatically generates test data. Migration team receives validated contracts as specifications. This eliminates manual test data creation per client.

Cost impact is significant: traditional approach takes weeks of manual test data creation per client migration. With this tool, it's hours to recapture and regenerate per client.

---

**Question:** "If the tool is using the migration 'clicks' to define what from the data model needs to be tested, for a specific version of the application, does that allow for reuse of the generated test data across different versions of the application for different scenarios, or are we creating a one shot test data set for one specific scenario?"

**Answer:**

Let me clarify something important first: we're not capturing clicks. We're capturing the database impact of either manually entered test cases or automatically run test automation scripts. The automated tests themselves need maintenance no matter what—that's unavoidable.

Now, regarding reuse: it happens at the specification level, not the dataset level.

What's reusable are the automated scenarios (test team maintains these anyway), generator expressions (how to vary data), contracts (component and field structures), and replay configurations (scale, customizations).

What gets regenerated per version are the actual datasets (schema may change), specific values (aligned with current constraints), and framework table sequences (BeInformed requirements).

Why this approach? Test data created today isn't futureproof for tomorrow. Schema changes, business rules evolve, constraints shift. Static datasets become technical debt. The advantage here is test data that evolves with applications through recapture and regeneration, maintaining alignment at minimal cost.

---

**Questions:** "If we are creating one shot test data sets, where do they land and how do we scrub them after use? If we are creating reusable sets, how are we managing and maintaining those sets?"

**Answer:**

We are creating one-shot test data sets, not reusable sets (because that's impossible—data becomes stale).

Replayed data lands in actual application tables (production-equivalent). We have full metadata tracking (runId, timestamps, status, record counts), so we know what was generated when. Currently cleanup is manual via database reset/restore.

How do we scrub them? Lifecycle needs more thought, honestly. I tend to keep track of generated test data so it can be removed based on certain characteristics (to be determined) and then fed with new data if required. We're looking at automated approaches—tagging for easy identification and deletion, isolation options (separate schemas/databases), maybe a promotion workflow (draft → validated → baseline → deprecated).

Every test data strategy requires lifecycle management. The difference here is metadata tracking is built-in from day one, making governance more manageable than manually created test data. For now, standard test database management practices apply—snapshots before large replays, restore to clean state as needed, or maintain separate test databases per scenario type.

---

**Question:** "Perhaps homing in on my key question - this feels very focused on the specific data migration scenario - not problem with that but does it have application beyond that scenario?"

**Answer:**

Data migration is really more of a side benefit. The primary purpose is synthetic test data generation.

Think of it this way: whether you're generating synthetic test data or migrating data from an old system, you need a contract to feed data to. Either synthetic data or data from an old system. The tool isn't restricted because it can also be used for data migration—it's more like killing two birds with one stone while also expanding our data migration capabilities.

Current applications for synthetic test data:

**Performance testing:** Generate 1000+ realistic records from one capture, test system behavior under load with production-equivalent data. This enables testing that was previously impossible without weeks of manual work.

**Regression testing:** Capture baseline scenarios from automated test suites, replay with variation for comprehensive coverage, integrate with existing test automation.

**Scalability validation:** Test architectural assumptions—does this hold at 1000 records? 10,000? Validate design decisions with realistic data volumes.

**Integration testing:** Consistent, reproducible datasets across test cycles while maintaining referential integrity across complex hierarchies.

**Client demonstrations:** Generate realistic demo data without exposing production information, customize to client industry and locale.

So yes, it has broad application. Migration just happens to be a valuable use case that proves the approach works.

---

**Question:** "After the discussion in Medellin, is this the action that was expected?"

**Answer:**

The objectives discussed on Wednesday January 21 during our Synthetic Test Data session were clear: for Anglo, generate large datasets to check if we can handle Papua. For MDES, generate representative XML files.

MDES/XML is not in scope of this particular synthetic test data tool. As discussed in Medellín, that's covered by another tool which may or may not be bundled with this one later.

The objective here is to generate representative test data at scale, systematize test data generation, and eliminate manual handcrafted artifacts. That's what we've delivered:

- Automated capture from production patterns
- Zero-configuration contract generation
- Scalable replay with referential integrity
- BeInformed-aware framework handling
- Extensible generator expression system
- Production-ready UI and workflow

This enables test automation integration with existing scenarios, performance testing with realistic data at scale, migration validation with production-equivalent patterns, and quality assurance through continuous testing aligned with application evolution.

This represents Phase 1—core capability with migration as the proving ground. Phase 2 expands to broader testing integration and enhanced distribution capabilities.

---

**Question:** "Have we had input and verification from all stakeholders? If this is specific to data migration perhaps that is only Guido and Maud, but if it is for broader application have we taken input from other resources?"

**Answer:**

Current stakeholders are limited to the members of the Blyce 2030 - Synthetic Data initiative, test automation team, and data migration team. That's the core group that's been involved so far.

But given the broader applications, we should probably engage additional stakeholders: QA/test leads for regression testing strategy alignment, DevOps/Platform for deployment and operational requirements, Product/architecture for strategic roadmap and investment prioritization, and Security/GDPR for synthetic data guarantees and compliance.

Next step would be to broaden stakeholder engagement to match the tool's capabilities. Current positioning as primarily a migration tool limits adoption and undervalues the broader testing applications already supported.

---

**Questions:** "Will we be able to add more variance in here, names are good, but we will need a range of variance for proper testing (birth dates etc)? For names - I see we have taxpayer 1, 2, 3 etc - can we either turn that to a, b, c, or a random string generator?"

**Answer:**

The generator expression system already supports variance through configurable expressions. You can cycle through predefined values, randomly select from options, combine fields from different parts of the data structure, use sequential numbering with custom formatting, or generate random numeric ranges.

Example: instead of "taxpayer 1/2/3" you configure surname to cycle through Jansen, De Vries, Bakker, Visser, Smit, and firstNames to cycle through Jan, Pieter, Anna, Maria, Hendrik. Then you combine them: surname + ', ' + firstNames. Result: "Jansen, Jan", "De Vries, Pieter", "Bakker, Anna".

**[EXPRESSION EDITOR IMAGE PLACEHOLDER]**

*The expression editor interface allows you to configure generator expressions for each field. You can select from predefined expression types (pool, pick, concat, seq, random) and customize parameters to control how data varies across replays.*

There's a lot of room to expand and be more creative and representative in this area. Planned enhancements include date distributions with realistic ranges (birth dates, registration dates), correlated values (age ↔ taxpayer type consistency), locale-aware libraries (built-in Dutch names, addresses), and statistical distributions (normal, weighted, custom).

The expression parser is extensible, so distribution design is the next logical enhancement.

---

## What to do from here

Broaden stakeholder engagement beyond the Blyce 2030 - Synthetic Data initiative to include QA/test leads, DevOps/Platform, and Product/architecture. Position this as a synthetic test data generation capability with migration as a valuable side benefit, not the other way around. 

Phase 2 should focus on enhanced distributions (date ranges, correlated values, locale-aware libraries), data lifecycle governance (automated cleanup, tagging), and deeper integration with test automation workflows. The core capability is proven; now it's about scaling adoption and refining the distribution mechanisms.

Deploy internal-first for synthetic test data generation in Blyce environments. For migration projects, deploy at client sites as needed. Deliver contracts and datasets as deliverables, not the tool itself, to reduce client friction.

---

## Why database-level generation instead of APIs?

The tool works at the database level, not through application APIs. The rationale is simple: calling APIs isn't fast enough to generate data at scale. When you need to create 1000+ records with complex hierarchies and referential integrity, API calls become a bottleneck.

The database approach comes with a risk though. The results must be tested, because it may contain generated data which is not valid for the application. The tool maintains referential integrity and respects database constraints, but it doesn't know about application-level business rules that aren't enforced in the database schema. That's why validation is important—generate at scale at the database level, then validate through the application to catch any edge cases.
