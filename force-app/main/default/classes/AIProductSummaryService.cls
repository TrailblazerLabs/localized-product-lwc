/**
 * Generates and stores localized AI summaries for Product2 records.
 */
public with sharing class AIProductSummaryService {
  @TestVisible
  private static final String TEMPLATE_DEVELOPER_NAME = 'AI_Product_Summary_Generator';
  @TestVisible
  private static final String DEFAULT_AUDIENCE = 'sales rep';

  @TestVisible
  private static PromptTemplateInvoker promptTemplateInvoker = new ConnectApiPromptTemplateInvoker();
  @TestVisible
  private static ProductSelector productSelector = new SoqlProductSelector();

  @TestVisible
  private interface PromptTemplateInvoker {
    ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generate(
      String templateDeveloperName,
      ConnectApi.EinsteinPromptTemplateGenerationsInput input
    );
  }

  private class ConnectApiPromptTemplateInvoker implements PromptTemplateInvoker {
    public ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generate(
      String templateDeveloperName,
      ConnectApi.EinsteinPromptTemplateGenerationsInput input
    ) {
      return ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
        templateDeveloperName,
        input
      );
    }
  }

  @TestVisible
  private interface ProductSelector {
    List<Product2> selectById(Id productId);
  }

  private class SoqlProductSelector implements ProductSelector {
    public List<Product2> selectById(Id productId) {
      return [
        SELECT Id, Name, Description, Family, ProductCode, Digital_Product__c
        FROM Product2
        WHERE Id = :productId
        WITH USER_MODE
        LIMIT 1
      ];
    }
  }

  /**
   * Generates an AI-powered product summary for the given Product2 record and language.
   * @param productId The Id of the Product2 record.
   * @param language The language code (e.g., 'en', 'es', 'fr').
   * @return AIProductSummaryResult DTO with summary and metadata.
   */
  @AuraEnabled
  public static AIProductSummaryResult generateSummary(
    Id productId,
    String language
  ) {
    AIProductSummaryResult result = new AIProductSummaryResult();
    result.productId = productId;
    result.language = normalizeLanguage(language);
    result.status = 'Pending';
    result.lastGeneratedOn = System.now();
    result.promptVersion = TEMPLATE_DEVELOPER_NAME;

    if (productId == null) {
      result.status = 'Error';
      result.statusMessage = 'productId is required.';
      return result;
    }

    if (String.isBlank(result.language)) {
      result.status = 'Error';
      result.statusMessage = 'language is required.';
      return result;
    }
    if (!Schema.sObjectType.Product2.isAccessible()) {
      result.status = 'Error';
      result.statusMessage = 'Insufficient access to Product2.';
      return result;
    }
    if (
      !Schema.sObjectType.Product2.fields.Name.isAccessible() ||
      !Schema.sObjectType.Product2.fields.Description.isAccessible() ||
      !Schema.sObjectType.Product2.fields.Family.isAccessible() ||
      !Schema.sObjectType.Product2.fields.ProductCode.isAccessible() ||
      !Schema.sObjectType.Product2.fields.Digital_Product__c.isAccessible()
    ) {
      result.status = 'Error';
      result.statusMessage = 'Insufficient field access for Product2 summary generation.';
      return result;
    }

    List<Product2> products = productSelector.selectById(productId);
    if (products.isEmpty()) {
      result.status = 'Error';
      result.statusMessage =
        'Product not found for Id: ' + String.valueOf(productId);
      return result;
    }
    Product2 product = products[0];
    result.productName = product.Name;

    Map<String, String> abbreviationMap = getAbbreviationMapForLanguage(
      result.language
    );
    String abbreviationContext = buildAbbreviationContext(abbreviationMap);

    ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output;
    try {
      output = invokeTemplate(product, result.language, abbreviationContext);
    } catch (ConnectApi.ConnectApiException e) {
      result.status = 'Error';
      result.statusMessage = 'Prompt Builder invocation failed.';
      return result;
    }

    if (
      output == null ||
      output.generations == null ||
      output.generations.isEmpty()
    ) {
      result.status = 'Error';
      result.statusMessage = 'Prompt Builder returned no generations.';
      return result;
    }

    String rawText = output.generations[0].text;
    applyParsedOutput(result, rawText, abbreviationMap);
    if (result.status == 'Error') {
      return result;
    }
    result.lastGeneratedOn = System.now();
    result.status = 'Success';
    result.statusMessage = 'Summary generated.';
    return result;
  }

  @AuraEnabled
  public static AIProductSummaryResult saveSummary(
    Id productId,
    String language,
    String approvedSummary
  ) {
    AIProductSummaryResult result = new AIProductSummaryResult();
    result.productId = productId;
    result.language = normalizeLanguage(language);
    result.lastGeneratedOn = System.now();

    if (productId == null) {
      result.status = 'Error';
      result.statusMessage = 'productId is required.';
      return result;
    }
    if (String.isBlank(result.language)) {
      result.status = 'Error';
      result.statusMessage = 'language is required.';
      return result;
    }
    if (String.isBlank(approvedSummary)) {
      result.status = 'Error';
      result.statusMessage = 'approvedSummary is required.';
      return result;
    }
    if (!Schema.sObjectType.Product2.isUpdateable()) {
      result.status = 'Error';
      result.statusMessage = 'Insufficient permissions to update Product2.';
      return result;
    }

    String targetField = resolveSummaryField(result.language);
    if (targetField == null) {
      result.status = 'Error';
      result.statusMessage =
        'Unsupported language for MVP storage: ' + result.language;
      return result;
    }
    if (
      !Schema.sObjectType.Product2.fields.getMap().containsKey(targetField) ||
      !Schema.sObjectType.Product2.fields.getMap()
        .get(targetField)
        .getDescribe()
        .isUpdateable()
    ) {
      result.status = 'Error';
      result.statusMessage =
        'Insufficient field update access for ' +
        targetField +
        '.';
      return result;
    }

    Product2 updateRow = new Product2(Id = productId);
    updateRow.put(targetField, approvedSummary);
    try {
      update updateRow;
    } catch (DmlException e) {
      result.status = 'Error';
      result.statusMessage = 'Failed to save summary.';
      return result;
    }

    result.summary = approvedSummary;
    result.status = 'Success';
    result.statusMessage = 'Summary saved.';
    return result;
  }

  @TestVisible
  private static ConnectApi.EinsteinPromptTemplateGenerationsRepresentation invokeTemplate(
    Product2 product,
    String language,
    String abbreviationContext
  ) {
    Map<String, Object> productPayload = new Map<String, Object>{
      'Id' => product.Id,
      'Name' => product.Name,
      'Description' => product.Description,
      'Family' => product.Family,
      'ProductCode' => product.ProductCode,
      'DigitalProduct' => product.Digital_Product__c
    };

    ConnectApi.WrappedValue productValue = new ConnectApi.WrappedValue();
    productValue.value = productPayload;

    ConnectApi.WrappedValue languageValue = new ConnectApi.WrappedValue();
    languageValue.value = language;

    ConnectApi.WrappedValue audienceValue = new ConnectApi.WrappedValue();
    audienceValue.value = DEFAULT_AUDIENCE;

    ConnectApi.WrappedValue abbreviationValue = new ConnectApi.WrappedValue();
    abbreviationValue.value = abbreviationContext;

    Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>{
      'Input:Product' => productValue,
      'Input:Language' => languageValue,
      'Input:Audience' => audienceValue,
      'Input:AbbreviationContext' => abbreviationValue
    };

    ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
    input.inputParams = inputParams;
    input.isPreview = false;
    input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
    input.additionalConfig.applicationName = 'PromptBuilderPreview';

    return promptTemplateInvoker.generate(TEMPLATE_DEVELOPER_NAME, input);
  }

  @TestVisible
  private static void applyParsedOutput(
    AIProductSummaryResult result,
    String rawText,
    Map<String, String> approvedExpansions
  ) {
    if (String.isBlank(rawText)) {
      result.status = 'Error';
      result.statusMessage = 'Model returned empty output.';
      return;
    }

    Map<String, Object> parsed = parseJson(rawText);

    result.summary = asString(parsed.get('summary'));
    if (String.isBlank(result.summary)) {
      result.status = 'Error';
      result.statusMessage = 'Model output did not include a usable summary.';
      return;
    }
    result.bestFitCustomer = asString(parsed.get('bestFitCustomer'));
    result.positioningBullets = asStringList(parsed.get('positioningBullets'));
    result.warnings.addAll(asStringList(parsed.get('warnings')));

    Map<String, String> candidateTerms = asStringMap(
      parsed.get('decodedTerms')
    );
    for (String key : candidateTerms.keySet()) {
      if (approvedExpansions.containsKey(key)) {
        result.decodedTerms.put(key, approvedExpansions.get(key));
      } else {
        result.warnings.add(
          'No approved expansion found for abbreviation: ' + key
        );
      }
    }
  }

  @TestVisible
  private static Map<String, String> getAbbreviationMapForLanguage(
    String language
  ) {
    Map<String, String> expansions = new Map<String, String>();
    Map<String, String> generic = new Map<String, String>();
    Map<String, String> specific = new Map<String, String>();
    List<Product_Abbreviation_Map__mdt> records = Product_Abbreviation_Map__mdt.getAll()
      .values();

    for (Product_Abbreviation_Map__mdt row : records) {
      if (
        !row.Active__c ||
        String.isBlank(row.Abbreviation__c) ||
        String.isBlank(row.Expansion__c)
      ) {
        continue;
      }

      if (!matchesLanguage(row.Language__c, language)) {
        continue;
      }

      String abbreviation = row.Abbreviation__c.trim();
      String expansion = row.Expansion__c.trim();
      if (String.isBlank(row.Language__c)) {
        if (!generic.containsKey(abbreviation)) {
          generic.put(abbreviation, expansion);
        }
      } else if (
        normalizeLanguage(row.Language__c) == normalizeLanguage(language)
      ) {
        if (!specific.containsKey(abbreviation)) {
          specific.put(abbreviation, expansion);
        }
      }
    }

    expansions.putAll(generic);
    expansions.putAll(specific);
    return expansions;
  }

  @TestVisible
  private static Boolean matchesLanguage(
    String rowLanguage,
    String requestedLanguage
  ) {
    if (String.isBlank(rowLanguage)) {
      return true;
    }
    return normalizeLanguage(rowLanguage) ==
      normalizeLanguage(requestedLanguage);
  }

  @TestVisible
  private static String buildAbbreviationContext(
    Map<String, String> abbreviations
  ) {
    if (abbreviations == null || abbreviations.isEmpty()) {
      return '';
    }
    List<String> keys = new List<String>(abbreviations.keySet());
    keys.sort();
    List<String> lines = new List<String>();
    for (String key : keys) {
      lines.add(key + ' = ' + abbreviations.get(key));
    }
    return String.join(lines, '\n');
  }

  @TestVisible
  private static String normalizeLanguage(String value) {
    if (String.isBlank(value)) {
      return null;
    }

    String raw = value.trim().toLowerCase();
    if (raw == 'en' || raw == 'english') {
      return 'English';
    }
    if (raw == 'es' || raw == 'spanish') {
      return 'Spanish';
    }
    if (
      raw == 'pt' ||
      raw == 'pt-br' ||
      raw == 'portuguese' ||
      raw == 'portugues'
    ) {
      return 'Portuguese';
    }
    if (raw == 'hi' || raw == 'hindi') {
      return 'Hindi';
    }
    return value.trim();
  }

  @TestVisible
  private static String resolveSummaryField(String normalizedLanguage) {
    if (normalizedLanguage == 'English') {
      return 'AI_Summary_English__c';
    }
    if (normalizedLanguage == 'Spanish') {
      return 'AI_Summary_Spanish__c';
    }
    if (normalizedLanguage == 'Portuguese') {
      return 'AI_Summary_Portuguese__c';
    }
    if (normalizedLanguage == 'Hindi') {
      return 'AI_Summary_Hindi__c';
    }
    return null;
  }

  @TestVisible
  private static Map<String, Object> parseJson(String body) {
    try {
      Object parsed = JSON.deserializeUntyped(body);
      if (parsed instanceof Map<String, Object>) {
        return (Map<String, Object>) parsed;
      }
      return new Map<String, Object>{
        'summary' => body,
        'warnings' => new List<Object>{
          'Model output JSON was not an object; raw text stored as summary.'
        }
      };
    } catch (System.JSONException e) {
      return new Map<String, Object>{
        'summary' => body,
        'warnings' => new List<Object>{
          'Model output was non-JSON; summary stored as raw text.'
        }
      };
    }
  }

  @TestVisible
  private static String asString(Object value) {
    return (value == null) ? null : String.valueOf(value);
  }

  @TestVisible
  private static List<String> asStringList(Object value) {
    List<String> out = new List<String>();
    if (!(value instanceof List<Object>)) {
      return out;
    }
    for (Object item : (List<Object>) value) {
      out.add(String.valueOf(item));
    }
    return out;
  }

  @TestVisible
  private static Map<String, String> asStringMap(Object value) {
    Map<String, String> out = new Map<String, String>();
    if (!(value instanceof Map<String, Object>)) {
      return out;
    }
    Map<String, Object> raw = (Map<String, Object>) value;
    for (String key : raw.keySet()) {
      out.put(String.valueOf(key), String.valueOf(raw.get(key)));
    }
    return out;
  }
}
