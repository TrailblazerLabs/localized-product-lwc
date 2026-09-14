# AI-Driven Localized Product Summarizer

![Salesforce](https://img.shields.io/badge/Salesforce-Lightning-0D9DDA?logo=salesforce&logoColor=white)
![Agentforce](https://img.shields.io/badge/AI-Prompt%20Builder-6F2DBD)
![Languages](https://img.shields.io/badge/Languages-4-2E844A)
![License](https://img.shields.io/badge/License-Apache%202.0-blue)

## Overview

AI-Driven Localized Product Summarizer transforms complex Salesforce Product records into clear, sales-ready descriptions. Using Prompt Builder and grounded Product data, it generates customer-friendly summaries, identifies ideal audiences, explains approved abbreviations, and creates localized content in English, Spanish, Portuguese, and Hindi.

The experience keeps a human in control: AI generates the draft, a user reviews and edits it, and nothing is written to the Product record until the user selects **Save**.

## The Problem It Solves

Sales representatives often have to interpret technical, inconsistent, or incomplete product data on the fly. That makes it harder to understand what a product does, who it is for, and how to position it consistently.

This solution turns raw product information into useful selling guidance:

- a concise, customer-friendly summary
- the best-fit customer or audience
- positioning bullets for sales conversations
- approved explanations for unfamiliar abbreviations
- warnings when source data is missing or uncertain
- localized content for multilingual teams and experiences

## See It in Action

1. Open a Product record.
2. Choose English, Spanish, Portuguese, or Hindi.
3. Select **Generate**.
4. Review the summary, customer fit, positioning bullets, decoded terms, and warnings.
5. Edit the draft if needed and select **Save**.

> Add a Loom, YouTube, or Salesforce demo video here when one is available.

## What Is Included

| Component                       | Purpose                                                                                              |
| ------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `aiProductSummarizer`           | Lightning Web Component for selecting a language, generating content, reviewing it, and saving it    |
| `AIProductSummaryService`       | Secure Apex orchestration for Product grounding, Prompt Builder invocation, parsing, and persistence |
| `AIProductSummaryResult`        | Typed response contract shared by Apex and the LWC                                                   |
| `AI_Product_Summary_Generator`  | Prompt Builder template with structured JSON output and multilingual instructions                    |
| `Product_Abbreviation_Map__mdt` | Custom metadata for administrator-approved terminology                                               |
| Product fields                  | Grounding inputs and language-specific summary storage                                               |
| `Localized_Product_AI_User`     | Least-privilege permission set for the included Apex and Product fields                              |
| Apex and Jest tests             | Automated validation for server-side and client-side behavior                                        |

## Architecture at a Glance

```text
Product2 record
      ↓
AI Product Summarizer LWC
      ↓ Generate
AIProductSummaryService
      ├── grounded Product fields
      ├── approved abbreviation custom metadata
      └── Prompt Builder template
                    ↓ structured response
            Human review and editing
                    ↓ Save
      Product2.AI_Summary_<Language>__c
```

For implementation details, see [Architecture](docs/ARCHITECTURE.md). For the administrator and user workflow, see the [User Guide](docs/USER-GUIDE.md).

## Quick Start Guide

### Prerequisites

- A Salesforce org with Einstein generative AI and Prompt Builder enabled
- Access to the standard `Product2` object
- A Salesforce license or add-on that supports executing Prompt Builder templates
- Permission to deploy metadata and customize Lightning record pages
- For local development: Salesforce CLI v2 and Node.js 20 or later

### Before You Deploy

This repository includes the custom Product fields used by the prompt. If your target org already has fields with the same API names, compare their types before deployment. Salesforce cannot convert an existing field between incompatible types during a metadata deployment.

The included Publisher, Platform, and Imprint picklists contain neutral example values. Replace or extend them with your organization's approved taxonomy.

### Option 1: Deploy from GitHub

Use the community-operated GitHub Salesforce Deploy Tool to deploy the default branch without installing local developer tools:

<a href="https://githubsfdeploy.herokuapp.com/app/githubdeploy/TrailblazerLabs/localized-product-lwc?ref=main">
  <img alt="Deploy to Salesforce" src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png">
</a>

1. Select **Production / Developer** or **Sandbox**.
2. Sign in to the intended Salesforce org.
3. Review the components presented by the tool.
4. Confirm the deployment.
5. Complete the post-installation steps below.

> This button uses a third-party, open-source deployment service. Organizations that do not permit third-party deployment tools should use the Salesforce CLI option.

### Option 2: Install with Salesforce CLI

1. Clone the repository and enter the project directory:

   ```bash
   git clone https://github.com/TrailblazerLabs/localized-product-lwc.git
   cd localized-product-lwc
   ```

2. Authenticate to the target org if it is not already connected:

   ```bash
   sf org login web --alias localized-product-target
   ```

   For a sandbox, use its My Domain login URL or the sandbox login endpoint required by your organization.

3. Validate the deployment without changing the org:

   ```bash
   sf project deploy start \
     --source-dir force-app \
     --target-org localized-product-target \
     --dry-run \
     --test-level RunSpecifiedTests \
     --tests AIProductSummaryServiceTest
   ```

4. Deploy the solution:

   ```bash
   sf project deploy start \
     --source-dir force-app \
     --target-org localized-product-target \
     --test-level RunSpecifiedTests \
     --tests AIProductSummaryServiceTest
   ```

5. Assign the included permission set:

   ```bash
   sf org assign permset \
     --name Localized_Product_AI_User \
     --target-org localized-product-target
   ```

### Post-Installation Steps

1. In Setup, confirm that Einstein generative AI is enabled.
2. Open **Prompt Builder** and verify that **AI Product Summary Generator** is active.
3. Give users the Salesforce-provided Prompt Template User permission or entitlement supported by their license. This is separate from the included permission set.
4. Assign `Localized_Product_AI_User` to each intended user.
5. Open a Product Lightning record page in Lightning App Builder.
6. Add **AI Product Summarizer** to the page and activate the page for the desired apps and profiles.
7. Review the `Product Abbreviation Map` custom metadata examples and add approved terminology for your organization.
8. Replace the neutral Publisher, Platform, and Imprint values with your approved taxonomy.
9. Populate meaningful Product data before testing the first generation.

## Product Data Used for Grounding

The prompt can use standard Product information and the included custom fields, such as:

- Product name, code, description, family, status, and type
- author, publisher, imprint, subject, and grade level
- ISBN, binding format, material type, and page count
- platform and digital-product indicator

Generated summaries are stored independently in:

- `AI_Summary_English__c`
- `AI_Summary_Spanish__c`
- `AI_Summary_Portuguese__c`
- `AI_Summary_Hindi__c`

## Customize the Solution

### Add Approved Abbreviations

Create `Product Abbreviation Map` custom metadata records with the abbreviation, its approved expansion, an optional language, and the Active flag enabled. Generic records apply to every language; language-specific records take precedence when the selected language matches.

### Tune the Prompt

Clone or revise `AI Product Summary Generator` in Prompt Builder to adjust tone, audience, output requirements, or grounding. Preserve these JSON keys unless you also update `AIProductSummaryService`:

- `summary`
- `bestFitCustomer`
- `positioningBullets`
- `decodedTerms`
- `warnings`

### Add Another Language

Update the LWC options, Apex language routing, prompt instructions, summary field metadata, permission set, and tests. Keep each language in its own Product summary field to prevent content from being saved to the wrong destination.

## Responsible AI and Security

- Product data grounds the prompt; the template tells the model not to invent unsupported claims.
- Missing or uncertain source information is surfaced as warnings.
- Users review and may edit every response before saving.
- Generated content is never saved automatically.
- Apex runs `with sharing`, queries in user mode, and checks object and field access.
- User-facing errors do not expose internal prompt or exception details.
- The repository contains no credentials, access tokens, org identifiers, or organization-specific sample data.

## Local Development and Validation

Install dependencies and run the client-side checks:

```bash
npm install
npm run lint
npm test
npm run prettier:verify
```

Run the Salesforce deployment validation shown in the CLI installation section before opening a pull request. The included test suites cover all four languages, generation and save behavior, parsing, validation, and safe error handling.

## Troubleshooting

| Symptom                                       | What to Check                                                                                             |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Generate is disabled                          | Confirm the component is on a saved Product record                                                        |
| Prompt Builder invocation failed              | Confirm Einstein is enabled, the template is active, and the user can execute prompt templates            |
| Insufficient Product access                   | Assign `Localized_Product_AI_User` and confirm the base license permits Product access                    |
| Deployment reports an incompatible field type | Compare the existing field with the repository metadata and retain the target org's compatible definition |
| Summary is generic or incomplete              | Populate meaningful Product grounding fields and maintain approved abbreviation records                   |
| Save is disabled                              | Generate a result for the selected language and ensure the summary is not blank                           |

## Project Structure

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

## About the Creator

Built by [@ssisson](https://github.com/ssisson) as part of the Trailblazer Labs Builder in Residence Cohort.

## Contributing

Contributions are welcome. Review [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Trailblazer Labs requires contributors to sign its CLA before a pull request can be merged.

## License

Licensed under the Apache License 2.0. See [LICENSE](LICENSE).
