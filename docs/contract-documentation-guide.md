# Data Contract Documentation Guide

## Overview

The data contract documentation page provides a comprehensive, customer-facing view of the data structure required for migration scenarios. It's accessible at:

```
http://localhost:3000/contract/[runId]
```

Example:
```
http://localhost:3000/contract/D57E275A-3341-41A2-9654-7FC61D5EE946
```

## What the Contract Covers

The current contract documentation includes:

### ✅ Currently Included

1. **Component Structure**
   - Component name and description
   - Physical table mapping
   - Cardinality (min/max occurrences)
   - Required vs optional components

2. **Field Specifications**
   - Field name (logical and physical column)
   - Data type (string, integer, date, etc.)
   - Maximum length constraints
   - Required/optional indicator
   - Example values
   - Foreign key relationships

3. **Summary Statistics**
   - Total number of components
   - Total number of fields
   - Count of required fields

4. **Visual Indicators**
   - Required fields marked with asterisk (*)
   - Foreign key fields marked with "FK" badge
   - Color-coded field types and requirements

## Additional Information That Would Help Customers

### 🎯 Recommended Enhancements

1. **Data Validation Rules**
   - Format patterns (e.g., email, phone number, postal code)
   - Value ranges for numeric fields
   - Date range constraints
   - Enumerated value lists (e.g., valid status codes)

2. **Business Rules & Dependencies**
   - Conditional requirements (e.g., "Field X required if Field Y is provided")
   - Cross-field validation rules
   - Business logic constraints

3. **Data Mapping Guidance**
   - Source system field mappings
   - Transformation examples
   - Common data quality issues and how to resolve them

4. **Sample Data Files**
   - CSV/Excel templates with headers
   - Sample records showing valid data
   - Invalid data examples with explanations

5. **Lookup/Reference Tables**
   - Valid values for coded fields
   - Country codes, status codes, type codes
   - Lookup table documentation

6. **Data Quality Requirements**
   - Uniqueness constraints
   - Null handling rules
   - Default values
   - Data cleansing recommendations

7. **Migration Process Context**
   - How this data will be used
   - Impact of missing optional fields
   - Performance considerations for large datasets

8. **Change History**
   - Contract version history
   - What changed between versions
   - Migration path for existing data

## How to Expose the Documentation Page

### Current Implementation

The documentation page is already exposed at `/contract/[runId]`. To access it:

1. Navigate to: `http://localhost:3000/contract/D57E275A-3341-41A2-9654-7FC61D5EE946`
2. Replace the runId with your specific migration scenario run ID

### Features

- **Print-friendly**: Click the Print button for a PDF-ready version
- **Responsive design**: Works on desktop, tablet, and mobile
- **Professional styling**: Clean, modern design suitable for customer-facing documentation
- **Comprehensive**: Shows all components, fields, and relationships

### Sharing with Customers

You can share the contract documentation by:

1. **Direct Link**: Send the URL to customers
2. **PDF Export**: Use the Print button to save as PDF
3. **Embedded**: Embed in your customer portal or documentation site

### Adding to Navigation

To make the contract documentation easily discoverable, you could:

1. Add a link in the main navigation menu
2. Add a "View Contract" button in the Replay Wizard
3. Create a contracts list page showing all available contracts

## API Endpoint

The contract data is available via API at:

```
GET /api/contract?runId={runId}&objectKey={objectKey}
```

Response includes:
- `contractJson`: Full contract structure as JSON
- `mappings`: Field mappings with physical table/column information

## Future Enhancements

### Potential Additions

1. **Interactive Examples**
   - Live data validation
   - Sample data generator
   - Format converter tools

2. **Multi-language Support**
   - Translate field descriptions
   - Localized examples
   - Regional format guidance

3. **Data Submission Interface**
   - Upload CSV/Excel files
   - Validate against contract
   - Preview data before migration

4. **Versioning & Comparison**
   - Compare different contract versions
   - Show what changed
   - Migration guides between versions

5. **Integration Documentation**
   - API endpoints for data submission
   - Authentication requirements
   - Rate limits and quotas

6. **Automated Testing**
   - Validate sample files against contract
   - Generate test data
   - Data quality reports

## Bidirectional Relationship: Contract ↔ Replay Wizard

The contract and replay wizard have a strong bidirectional relationship:

### Contract → Replay Wizard
- The contract defines the expected data structure
- The replay wizard uses the contract to configure field generators
- All fields in the contract can be configured with generators in the wizard
- Excluded fields from the contract will use original captured values

### Replay Wizard → Contract
- Generator configurations in the wizard are stored in the domain model
- These configurations become part of the contract documentation
- Changes in the wizard update what customers see in the contract

### Data Delivery Options

**Option 1: JSON Data Delivery**
- Customers provide data matching the contract structure
- JSON format follows the component/field hierarchy
- Required fields must be provided
- Optional fields can be omitted (will use captured values)

**Option 2: Generated Data**
- Use the replay wizard to configure generators
- Data is generated automatically during migration
- Generators can reference other fields (ctx expressions)
- Mix of provided and generated data is supported

**Option 3: Hybrid Approach**
- Provide some fields via JSON
- Generate others via wizard configuration
- Excluded fields automatically use captured values
- Maximum flexibility for customers

### Example JSON Structure

```json
{
  "individual": {
    "firstNames": "John",
    "surname": "Doe",
    "dateOfBirth": "1980-01-15"
  },
  "properties": {
    "filename": "Doe, John",
    "casestatus": "SPConcept"
  }
}
```

### Example Generator Configuration

```
individual.firstNames: pool(firstNames.male)
individual.surname: pool(surnames.dutch)
individual.birthname: ctx(surname)
properties.filename: concat(ctx(surname), ', ', ctx(firstnames))
```

## Implementation Notes

The contract documentation page:
- Uses Next.js App Router with dynamic routes
- Fetches data from `/api/contract` endpoint
- Renders using React with Tailwind CSS
- Supports print styling for PDF generation
- Shows physical table/column mappings for technical users
- Highlights foreign key relationships that will be auto-generated
- Respects customization settings from localStorage
- Syncs with replay wizard generator configurations

## Maintenance

To update the contract documentation:

1. Modify domain model in database (MigrationDomainComponent, MigrationDomainField)
2. Update example values and notes
3. Refresh the page - changes appear immediately
4. No code changes needed for content updates
