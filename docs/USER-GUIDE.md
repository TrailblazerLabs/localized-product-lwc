# User Guide

## Administrator setup

1. Deploy `force-app`.
2. Assign `Localized_Product_AI_User` to intended users.
3. Assign Salesforce's Prompt Template User entitlement/permission supported by your org and license.
4. Confirm that Einstein generative AI is enabled.
5. Open Prompt Builder and confirm **AI Product Summary Generator** is active.
6. Add **AI Product Summarizer** to a Product record page and activate the page.
7. Review the example `Product Abbreviation Map` custom metadata records and add your approved terminology.
8. Replace the neutral Publisher, Platform, and Imprint picklist examples with your organization's approved values.

## Generate and save a summary

1. Open a Product record.
2. Select English, Spanish, Portuguese, or Hindi.
3. Select **Generate**.
4. Review the proposed summary, positioning information, decoded terms, and warnings.
5. Edit the summary if necessary.
6. Select **Save** to store the approved text in the language-specific Product field.

Changing the selected language clears the previously generated draft so content is never saved into the wrong language field.

## Troubleshooting

- **Generate is disabled:** Confirm the component is on a saved Product record.
- **Prompt Builder invocation failed:** Confirm Einstein is enabled, the prompt template is active, and the user has the Salesforce Prompt Template User entitlement/permission.
- **Insufficient access:** Assign `Localized_Product_AI_User` and confirm the user's base license permits Product access.
- **No useful summary:** Populate meaningful Product name, description, family, product code, and other grounded fields before generating again.
