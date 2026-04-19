# Scenario Studio - Migration Data Capture & Replay Framework

## How to Start the Project

**Prerequisites:**
- SQL Server running on `localhost:1433` with database `gd_mts` (configure credentials via local `.env` / `.env.local`, not in source control)
- Node.js and npm installed
- Docker Desktop with WSL2 (for Windows environment)

**Start the Application:**

1. **Start the Next.js development server:**
   ```powershell
   cd C:\dev\db\snapshot\ui\scenario-studio
   npm run dev
   ```
   The UI will be available at `http://localhost:3000`

2. **Access the application:**
   - Open your browser to `http://localhost:3000`
   - Navigate to "Runs" to see captured scenarios
   - Click on a run to access Capture, Analysis, and Replay tabs

---

## Overview
A comprehensive framework for capturing, analyzing, and replaying database migration scenarios for BeInformed applications. The system enables testing data migrations by capturing real production data patterns, generating synthetic test data, and replaying it with full referential integrity.

---

## Core Features

### 1. Scenario Capture
- **Live Database Monitoring**: Captures INSERT, UPDATE, and DELETE operations on tracked tables during a defined time window
- **Snapshot Comparison**: Uses SHA-256 hashing to detect changes between start and end states
- **Smart Filtering**: Excludes framework tables (qrtz_*, sys%, CMF*) and focuses on business data
- **Change Tracking**: Records all mutations with full JSON payloads and change types
- **Automatic Reuse**: Reuses snapshots from runs within the last 5 minutes to optimize performance

### 2. Data Dictionary & Contract Generation
- **Automatic Schema Discovery**: Analyzes captured data to build hierarchical component structures
- **Relationship Detection**: Identifies parent-child relationships through foreign keys
- **Field Analysis**: Determines data types, cardinality (min/max occurs), and required fields
- **Contract Documentation**: Generates comprehensive data contracts showing:
  - 13 components with 123 fields (for current capture)
  - Hierarchical structure with expand/collapse navigation
  - Field requirements, types, and constraints
  - Sample JSON and JSON Schema outputs
- **Customization Interface**: Allows excluding components/fields and reordering for contract refinement

### 3. Intelligent Data Generation
- **Generator Expression System**: Supports multiple generator types:
  - `ctx(fieldName)`: Use captured context values
  - `seq()`: Sequential numbering with optional prefix/suffix
  - `literal(value)`: Static values
  - `concat()`: Combine multiple generators and literals
  - `random()`, `pick()`, `pool()`: Various randomization strategies
- **Context-Aware Generation**: Automatically detects patterns and suggests appropriate generators
- **Pattern Recognition**: Identifies custom `ctx()` references across components
- **Preview Mode**: Shows generated data before execution with expandable component views

### 4. Migration Replay Engine
- **Multi-Record Replay**: Generate 1 to 1000+ test records from a single captured scenario
- **Referential Integrity**: Automatically maintains foreign key relationships across tables
- **Framework Table Handling**: Special handling for BeInformed framework tables:
  - CHANGES, MUTATION, CMF* tables replayed in exact captured order
  - Preserves IDENTITY dependencies
  - Maintains correct TOPICOFCHANGE values for mutation linkage
- **Primary Key Remapping**: Tracks old→new PK mappings and updates all FK references
- **Transaction Safety**: Each record replayed in its own transaction with proper error handling

### 5. Real-Time Progress Monitoring
- **Live Progress Indicator**: Shows current record being processed during replay
- **Detailed Logging**: Tracks each table insert with timing information
- **Error Reporting**: Comprehensive error messages with SQL context
- **Performance Metrics**: Displays total time and records per second

### 6. User Interface
- **Modern React/Next.js Frontend**: Built with TypeScript, TailwindCSS, and shadcn/ui components
- **Responsive Design**: Works across desktop and mobile devices
- **Intuitive Navigation**: Clear workflow from capture → analysis → customization → replay
- **Visual Feedback**: Color-coded status indicators, collapsible sections, and inline editing
- **Debug Console Logging**: Comprehensive client-side logging for troubleshooting

---

## Technical Architecture

### Backend (SQL Server)
**Stored Procedures:**
- `dbo.StartMigrationScenarioRun`: Initiates capture with snapshot creation
- `dbo.EndMigrationScenarioRun`: Finalizes capture and detects changes
- `dbo.GenerateContractFromCapture`: Builds data contracts from captured schemas
- `dbo.ReplayScenarioRun`: Core replay engine with FK remapping
- `dbo.ReplayDomainFast`: Optimized replay with inline generator parsing

**Tables:**
- `MigrationScenarioRun`: Run metadata and status
- `MigrationScenarioRow`: Captured row data with JSON payloads
- `MigrationScenarioSnapshot`: Baseline snapshots for comparison
- `MigrationDomainComponent/Field`: Contract definitions

### Frontend (Next.js 16)
- **App Router**: Modern file-based routing with dynamic routes
- **API Routes**: RESTful endpoints for contract generation, replay, and data fetching
- **Client Components**: Interactive UI with React hooks and state management
- **Server Components**: Optimized data fetching and rendering

---

## Key Innovations

1. **Inline Generator Parsing**: Parses generator expressions directly in SQL without external dependencies
2. **IDENTITY Preservation**: Maintains insertion order for framework tables with identity dependencies
3. **Hierarchical Contracts**: Automatically builds parent-child component relationships
4. **Pattern Detection**: Identifies and suggests `ctx()` references for custom fields
5. **Zero-Configuration Capture**: No manual schema definition required - learns from actual data

---

## Use Cases

- **Migration Testing**: Validate data migrations before production deployment
- **Load Testing**: Generate thousands of realistic test records
- **Data Anonymization**: Replay with modified generators to anonymize sensitive data
- **Schema Evolution**: Test schema changes with real data patterns
- **Integration Testing**: Create consistent test datasets for BeInformed applications

---

## Why Off-the-Shelf Data Generation Products Fall Short

Traditional data generation tools like Mockaroo, Faker, or generic test data generators cannot replicate what Scenario Studio achieves because:

### 1. **BeInformed Framework Awareness**
- **The Problem**: BeInformed applications have complex framework tables (CHANGES, MUTATION, CMF*) with strict IDENTITY dependencies where each record must reference the IDENTITY value from the previous insert
- **Why Generic Tools Fail**: Off-the-shelf tools don't understand these framework-specific requirements and cannot maintain the precise insertion order and cross-table IDENTITY linkage needed for valid BeInformed cases
- **Our Solution**: Framework tables are excluded from generator processing and replayed in exact captured order, preserving all IDENTITY dependencies and TOPICOFCHANGE values

### 2. **Context-Aware Cross-Table Relationships**
- **The Problem**: Business logic requires fields across different tables to be contextually related (e.g., `fileName` must be constructed from `surname` and `firstNames` from a different component)
- **Why Generic Tools Fail**: Standard generators create random data per table without understanding cross-table context or business rules
- **Our Solution**: The `ctx()` generator system allows fields to reference values from any component in the hierarchy, maintaining business logic consistency across the entire data structure

### 3. **Learning from Real Production Patterns**
- **The Problem**: Production data has specific patterns, distributions, and edge cases that are impossible to replicate with generic random data
- **Why Generic Tools Fail**: They generate synthetic data based on generic rules, not actual production behavior
- **Our Solution**: Captures real production scenarios including all mutations, relationships, and edge cases, then replays them with configurable variation while maintaining the original patterns

### 4. **Hierarchical Component Dependencies**
- **The Problem**: BeInformed data models have deep parent-child hierarchies (e.g., Individual → Person Identification → Home Address → Contact Information) where child records must reference parent PKs
- **Why Generic Tools Fail**: Most tools generate flat tables or simple one-level relationships, not complex multi-level hierarchies with automatic FK remapping
- **Our Solution**: Automatically detects and maintains hierarchical relationships, remapping all foreign keys as records are created, ensuring referential integrity across 13+ related components

### 5. **Transaction-Level Mutation Tracking**
- **The Problem**: BeInformed's "Load most recent mutation" handler requires CHANGES records with correct TOPICOFCHANGE values linking to specific mutations in precise order
- **Why Generic Tools Fail**: They don't understand mutation concepts or the need to create coordinated CHANGES/MUTATION records for each business transaction
- **Our Solution**: Captures and replays complete mutation chains, preserving the exact transaction structure needed for BeInformed's mutation handling

### 6. **Zero-Configuration Schema Discovery**
- **The Problem**: Complex enterprise schemas with 100+ fields across multiple tables require extensive manual configuration in generic tools
- **Why Generic Tools Fail**: Require manual schema definition, field type mapping, and relationship configuration
- **Our Solution**: Automatically discovers schema, relationships, cardinality, and data types from captured data - no manual configuration needed

### 7. **Inline SQL Generator Parsing**
- **The Problem**: Need to generate data directly in SQL Server without external dependencies or API calls
- **Why Generic Tools Fail**: Typically require external services, APIs, or client-side processing
- **Our Solution**: Parses and executes generator expressions entirely within SQL Server stored procedures, enabling high-performance bulk generation without external dependencies

### 8. **Snapshot-Based Change Detection**
- **The Problem**: Need to capture not just new records but also UPDATEs and DELETEs on existing data
- **Why Generic Tools Fail**: Focus on generating new data, not capturing changes to existing records
- **Our Solution**: Uses SHA-256 snapshot comparison to detect and capture all INSERT, UPDATE, and DELETE operations during a time window

---

## Current Status
Fully functional with all features working. Contract documentation displays all 13 components and 123 fields correctly. Replay engine handles framework tables with proper IDENTITY preservation. Ready for production use.
