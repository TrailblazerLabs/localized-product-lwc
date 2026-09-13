# Localized Product LWC

Localized Product LWC is a Salesforce solution that uses Prompt Builder to turn Product records into grounded, sales-ready summaries in English, Spanish, Portuguese, or Hindi. Users generate a draft, review and edit it, and explicitly save the approved summary back to the corresponding Product field.

## What it includes

- `aiProductSummarizer` Lightning Web Component for generation, review, and save
- Apex service and response DTO
- `AI Product Summary Generator` Prompt Builder template
- English, Spanish, Portuguese, and Hindi Product summary fields
- grounded abbreviation custom metadata with example records
- Product fields referenced by the prompt template
- least-privilege `Localized Product AI User` permission set
- Apex and Jest tests

## Prerequisites

- Salesforce org with Einstein generative AI and Prompt Builder enabled
- Salesforce CLI v2 for command-line installation
- Node.js 20 or later for local Jest and lint validation
- Users who run the feature need Salesforce's Prompt Template User entitlement/permission in addition to the included permission set

## Install

```bash
git clone https://github.com/TrailblazerLabs/localized-product-lwc.git
cd localized-product-lwc
npm install
sf project deploy start --source-dir force-app --target-org YOUR_ORG_ALIAS
sf org assign permset --name Localized_Product_AI_User --target-org YOUR_ORG_ALIAS
```

After deployment, verify that **AI Product Summary Generator** is active in Prompt Builder. Add **AI Product Summarizer** to a Product record page in Lightning App Builder and activate the page.

## Validate locally

```bash
npm test
npm run lint
npm run prettier:verify
sf project deploy start --dry-run --source-dir force-app \
  --test-level RunSpecifiedTests --tests AIProductSummaryServiceTest \
  --target-org YOUR_ORG_ALIAS
```

## How it works

1. A user opens a Product record and selects a language.
2. Apex supplies grounded Product data and approved abbreviation mappings to Prompt Builder.
3. The prompt returns structured JSON containing a summary, customer fit, positioning bullets, decoded terms, and warnings.
4. The LWC presents the response for human review.
5. The user explicitly saves the approved summary to the language-specific Product field.

The prompt instructs the model not to invent unsupported product claims and surfaces missing or uncertain source data as warnings. See [Architecture](docs/ARCHITECTURE.md) and [User Guide](docs/USER-GUIDE.md) for more detail.

## Project structure

```text
force-app/main/default/
├── classes/
├── customMetadata/
├── genAiPromptTemplates/
├── lwc/aiProductSummarizer/
├── objects/Product2/fields/
├── objects/Product_Abbreviation_Map__mdt/
└── permissionsets/
```

## Security and configuration

- No credentials, tokens, or Named Credential secrets are stored in this repository.
- Apex uses sharing and checks object and field access before reading or saving Product data.
- Generated text is not saved automatically; users review it before committing it to Product.
- Treat the included abbreviation records as examples and maintain approved terminology for your organization.
- Publisher, platform, and imprint picklist values are neutral placeholders; replace them with your organization's approved taxonomy after installation.

## License

Licensed under the Apache License 2.0. See [LICENSE](LICENSE).

## Creator

Built by Stephanie Sisson as part of the Trailblazer Labs Builder in Residence cohort.
