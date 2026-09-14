# Architecture

## Components

`aiProductSummarizer` runs on a `Product2` record page and calls `AIProductSummaryService` imperatively for user-initiated generation and save operations. `AIProductSummaryResult` is the Apex response contract returned to the component.

Generation invokes the `AI_Product_Summary_Generator` Prompt Builder template. The template is grounded with standard and solution-owned Product fields. `Product_Abbreviation_Map__mdt` supplies administrator-approved abbreviation expansions, with language-specific records overriding generic records.

## Data flow

```text
Product record
    ↓
aiProductSummarizer LWC
    ↓ generate
AIProductSummaryService
    ├── Product2 source fields
    ├── Product_Abbreviation_Map__mdt
    └── AI_Product_Summary_Generator
             ↓ structured JSON
Human review in LWC
             ↓ explicit save
Product2.AI_Summary_<Language>__c
```

## Security

- Apex runs `with sharing`.
- The service checks Product object and field access before querying or updating.
- The UI displays sanitized user-facing errors and does not expose prompt invocation details.
- The included permission set grants only the Apex, Product, and custom-field access needed by this feature.
- Prompt execution requires the Salesforce-provided Prompt Template User entitlement or permission set supported by the target org's license.

## Portability

The repository includes all custom Product fields referenced by the active prompt template, the custom metadata type and example records, the prompt template, Apex, LWC, and tests. Org-specific secrets are not required.
