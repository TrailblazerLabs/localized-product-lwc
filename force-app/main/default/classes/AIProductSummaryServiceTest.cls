@IsTest
private class AIProductSummaryServiceTest {
  private class ProductSelectorMock implements AIProductSummaryService.ProductSelector {
    private Product2 product;

    ProductSelectorMock(Product2 product) {
      this.product = product;
    }

    public List<Product2> selectById(Id productId) {
      if (product == null) {
        return new List<Product2>();
      }
      Assert.areEqual(
        product.Id,
        productId,
        'The requested Product Id should be passed to the selector'
      );
      return new List<Product2>{ product };
    }
  }

  private class PromptTemplateMock implements AIProductSummaryService.PromptTemplateInvoker {
    private String responseText;
    private Boolean returnNoGenerations;
    private Boolean returnNullResponse;

    PromptTemplateMock(
      String responseText,
      Boolean returnNoGenerations,
      Boolean returnNullResponse
    ) {
      this.responseText = responseText;
      this.returnNoGenerations = returnNoGenerations;
      this.returnNullResponse = returnNullResponse;
    }

    public ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generate(
      String templateDeveloperName,
      ConnectApi.EinsteinPromptTemplateGenerationsInput input
    ) {
      Assert.areEqual(
        AIProductSummaryService.TEMPLATE_DEVELOPER_NAME,
        templateDeveloperName,
        'The configured prompt template should be invoked'
      );
      Assert.isNotNull(input, 'Prompt input should be provided');
      Assert.isFalse(input.isPreview, 'Generation should not run as a preview');
      Assert.areEqual(
        4,
        input.inputParams.size(),
        'All prompt inputs should be provided'
      );

      if (returnNullResponse) {
        return null;
      }

      ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response = new ConnectApi.EinsteinPromptTemplateGenerationsRepresentation();
      response.generations = new List<ConnectApi.EinsteinLLMGenerationItemOutput>();
      if (!returnNoGenerations) {
        ConnectApi.EinsteinLLMGenerationItemOutput generation = new ConnectApi.EinsteinLLMGenerationItemOutput();
        generation.text = responseText;
        response.generations.add(generation);
      }
      return response;
    }
  }

  @IsTest
  static void shouldNormalizeLanguagesAndRouteFields() {
    Assert.areEqual(
      'English',
      AIProductSummaryService.normalizeLanguage(' en '),
      'English language code should normalize'
    );
    Assert.areEqual(
      'Spanish',
      AIProductSummaryService.normalizeLanguage('Spanish'),
      'Spanish name should normalize'
    );
    Assert.areEqual(
      'Portuguese',
      AIProductSummaryService.normalizeLanguage('pt-BR'),
      'Brazilian Portuguese code should normalize'
    );
    Assert.areEqual(
      'Hindi',
      AIProductSummaryService.normalizeLanguage('hi'),
      'Hindi code should normalize'
    );
    Assert.isNull(
      AIProductSummaryService.normalizeLanguage(' '),
      'Blank language should normalize to null'
    );
    Assert.areEqual(
      'French',
      AIProductSummaryService.normalizeLanguage(' French '),
      'Unknown languages should retain their trimmed value'
    );

    Map<String, String> expectedFields = new Map<String, String>{
      'English' => 'AI_Summary_English__c',
      'Spanish' => 'AI_Summary_Spanish__c',
      'Portuguese' => 'AI_Summary_Portuguese__c',
      'Hindi' => 'AI_Summary_Hindi__c'
    };
    for (String language : expectedFields.keySet()) {
      Assert.areEqual(
        expectedFields.get(language),
        AIProductSummaryService.resolveSummaryField(language),
        language + ' should route to its summary field'
      );
    }
    Assert.isNull(
      AIProductSummaryService.resolveSummaryField('French'),
      'Unsupported languages should not resolve to a field'
    );
  }

  @IsTest
  static void shouldBuildAndMatchAbbreviationContext() {
    Map<String, String> mappings = new Map<String, String>{
      'SKU' => 'Stock Keeping Unit',
      'LMS' => 'Learning Management System'
    };
    Assert.areEqual(
      'LMS = Learning Management System\nSKU = Stock Keeping Unit',
      AIProductSummaryService.buildAbbreviationContext(mappings),
      'Abbreviation context should be sorted'
    );
    Assert.areEqual(
      '',
      AIProductSummaryService.buildAbbreviationContext(null),
      'Null mappings should produce empty context'
    );
    Assert.areEqual(
      '',
      AIProductSummaryService.buildAbbreviationContext(
        new Map<String, String>()
      ),
      'Empty mappings should produce empty context'
    );
    Assert.isTrue(
      AIProductSummaryService.matchesLanguage(null, 'English'),
      'Generic mappings should match every language'
    );
    Assert.isTrue(
      AIProductSummaryService.matchesLanguage('en', 'English'),
      'Equivalent languages should match'
    );
    Assert.isFalse(
      AIProductSummaryService.matchesLanguage('Spanish', 'English'),
      'Different languages should not match'
    );
  }

  @IsTest
  static void shouldParseAndConvertUntypedOutput() {
    Assert.areEqual(
      'Structured',
      (String) AIProductSummaryService.parseJson('{"summary":"Structured"}')
        .get('summary'),
      'JSON object output should be preserved'
    );
    Assert.areEqual(
      '["array output"]',
      (String) AIProductSummaryService.parseJson('["array output"]')
        .get('summary'),
      'Non-object JSON should fall back to raw text'
    );
    Assert.areEqual(
      'raw model text',
      (String) AIProductSummaryService.parseJson('raw model text')
        .get('summary'),
      'Invalid JSON should fall back to raw text'
    );
    Assert.isNull(
      AIProductSummaryService.asString(null),
      'Null should remain null'
    );
    Assert.areEqual(
      '42',
      AIProductSummaryService.asString(42),
      'Scalar values should convert to strings'
    );
    Assert.areEqual(
      new List<String>{ 'one', '2' },
      AIProductSummaryService.asStringList(new List<Object>{ 'one', 2 }),
      'List values should convert item-by-item'
    );
    Assert.areEqual(
      0,
      AIProductSummaryService.asStringList('not a list').size(),
      'Non-list values should produce an empty list'
    );
    Assert.areEqual(
      '2',
      AIProductSummaryService.asStringMap(
          new Map<String, Object>{ 'count' => 2 }
        )
        .get('count'),
      'Map values should convert to strings'
    );
    Assert.areEqual(
      0,
      AIProductSummaryService.asStringMap('not a map').size(),
      'Non-map values should produce an empty map'
    );
  }

  @IsTest
  static void shouldApplyParsedOutputAndRejectInvalidOutput() {
    AIProductSummaryResult result = new AIProductSummaryResult();
    AIProductSummaryService.applyParsedOutput(
      result,
      '{"summary":"S","bestFitCustomer":"C","positioningBullets":["b1"],"decodedTerms":{"LMS":"Learning Management System","XYZ":"XYZ"},"warnings":["w1"]}',
      new Map<String, String>{ 'LMS' => 'Learning Management System' }
    );
    Assert.areEqual('S', result.summary, 'Summary should be parsed');
    Assert.areEqual(
      'Learning Management System',
      result.decodedTerms.get('LMS'),
      'Approved expansion should be retained'
    );
    Assert.isFalse(
      result.decodedTerms.containsKey('XYZ'),
      'Unapproved abbreviations should be excluded'
    );
    Assert.areEqual(
      2,
      result.warnings.size(),
      'All warnings should be retained'
    );

    AIProductSummaryResult emptyResult = new AIProductSummaryResult();
    AIProductSummaryService.applyParsedOutput(
      emptyResult,
      '',
      new Map<String, String>()
    );
    Assert.areEqual(
      'Model returned empty output.',
      emptyResult.statusMessage,
      'Empty output should be rejected'
    );

    AIProductSummaryResult missingResult = new AIProductSummaryResult();
    AIProductSummaryService.applyParsedOutput(
      missingResult,
      '{"bestFitCustomer":"C"}',
      new Map<String, String>()
    );
    Assert.areEqual(
      'Model output did not include a usable summary.',
      missingResult.statusMessage,
      'Output without a summary should be rejected'
    );
  }

  @IsTest
  static void shouldValidateGenerateInputs() {
    Test.startTest();
    AIProductSummaryResult missingId = AIProductSummaryService.generateSummary(
      null,
      'English'
    );
    AIProductSummaryResult missingLanguage = AIProductSummaryService.generateSummary(
      AIProductSummaryTestDataFactory.productId(),
      ' '
    );
    Test.stopTest();
    Assert.areEqual(
      'productId is required.',
      missingId.statusMessage,
      'A Product Id should be required'
    );
    Assert.areEqual(
      'language is required.',
      missingLanguage.statusMessage,
      'A language should be required'
    );
  }

  @IsTest
  static void shouldGenerateSummaryFromPromptOutput() {
    Product2 product = AIProductSummaryTestDataFactory.createProduct();
    AIProductSummaryService.productSelector = new ProductSelectorMock(product);
    AIProductSummaryService.promptTemplateInvoker = new PromptTemplateMock(
      '{"summary":"Localized summary","bestFitCustomer":"Faculty","positioningBullets":["Clear value"]}',
      false,
      false
    );
    Test.startTest();
    AIProductSummaryResult result = AIProductSummaryService.generateSummary(
      product.Id,
      'Hindi'
    );
    Test.stopTest();
    Assert.areEqual('Success', result.status, 'Generation should succeed');
    Assert.areEqual(
      'Localized summary',
      result.summary,
      'Generated summary should be parsed'
    );
    Assert.areEqual(
      product.Name,
      result.productName,
      'Result should identify the source product'
    );
  }

  @IsTest
  static void shouldHandleEmptyPromptGenerations() {
    Product2 product = AIProductSummaryTestDataFactory.createProduct();
    AIProductSummaryService.productSelector = new ProductSelectorMock(product);
    AIProductSummaryService.promptTemplateInvoker = new PromptTemplateMock(
      null,
      true,
      false
    );
    Test.startTest();
    AIProductSummaryResult result = AIProductSummaryService.generateSummary(
      product.Id,
      'English'
    );
    Test.stopTest();
    Assert.areEqual(
      'Prompt Builder returned no generations.',
      result.statusMessage,
      'Empty generations should return a safe error'
    );
  }

  @IsTest
  static void shouldHandleMissingProduct() {
    Test.startTest();
    AIProductSummaryResult result = AIProductSummaryService.generateSummary(
      AIProductSummaryTestDataFactory.productId(),
      'English'
    );
    Test.stopTest();
    Assert.isTrue(
      result.statusMessage.startsWith('Product not found for Id:'),
      'A missing Product should return a safe error'
    );
  }

  @IsTest
  static void shouldHandleNullPromptResponse() {
    Product2 product = AIProductSummaryTestDataFactory.createProduct();
    AIProductSummaryService.productSelector = new ProductSelectorMock(product);
    AIProductSummaryService.promptTemplateInvoker = new PromptTemplateMock(
      null,
      false,
      true
    );
    Test.startTest();
    AIProductSummaryResult result = AIProductSummaryService.generateSummary(
      product.Id,
      'English'
    );
    Test.stopTest();
    Assert.areEqual(
      'Prompt Builder returned no generations.',
      result.statusMessage,
      'A null prompt response should return a safe error'
    );
  }

  @IsTest
  static void shouldValidateSaveInputs() {
    Test.startTest();
    AIProductSummaryResult missingId = AIProductSummaryService.saveSummary(
      null,
      'English',
      'summary'
    );
    AIProductSummaryResult missingLanguage = AIProductSummaryService.saveSummary(
      AIProductSummaryTestDataFactory.productId(),
      ' ',
      'summary'
    );
    AIProductSummaryResult missingSummary = AIProductSummaryService.saveSummary(
      AIProductSummaryTestDataFactory.productId(),
      'English',
      ' '
    );
    Test.stopTest();
    Assert.areEqual(
      'productId is required.',
      missingId.statusMessage,
      'A Product Id should be required'
    );
    Assert.areEqual(
      'language is required.',
      missingLanguage.statusMessage,
      'A language should be required'
    );
    Assert.areEqual(
      'approvedSummary is required.',
      missingSummary.statusMessage,
      'An approved summary should be required'
    );
  }

  @IsTest
  static void shouldRejectUnsupportedSaveLanguage() {
    Test.startTest();
    AIProductSummaryResult unsupported = AIProductSummaryService.saveSummary(
      AIProductSummaryTestDataFactory.productId(),
      'French',
      'summary'
    );
    Test.stopTest();
    Assert.isTrue(
      unsupported.statusMessage.contains('Unsupported language'),
      'Unsupported storage language should return a safe error'
    );
  }

  @IsTest
  static void shouldReturnSafeErrorWhenSaveCannotComplete() {
    Test.startTest();
    AIProductSummaryResult result = AIProductSummaryService.saveSummary(
      AIProductSummaryTestDataFactory.productId(),
      'English',
      'summary'
    );
    Test.stopTest();
    Assert.areEqual('Error', result.status, 'Save should fail safely');
    Assert.isTrue(
      result.statusMessage == 'Failed to save summary.' ||
      result.statusMessage.startsWith('Insufficient field update access'),
      'The error should describe an inaccessible field or missing Product'
    );
  }
}
