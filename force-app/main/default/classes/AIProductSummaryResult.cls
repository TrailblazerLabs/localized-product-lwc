public with sharing class AIProductSummaryResult {
  @AuraEnabled
  public Id productId;
  @AuraEnabled
  public String productName;
  @AuraEnabled
  public String language;
  @AuraEnabled
  public String summary;
  @AuraEnabled
  public String bestFitCustomer;
  @AuraEnabled
  public List<String> positioningBullets;
  @AuraEnabled
  public Map<String, String> decodedTerms;
  @AuraEnabled
  public List<String> warnings;
  @AuraEnabled
  public String promptVersion;
  @AuraEnabled
  public Datetime lastGeneratedOn;
  @AuraEnabled
  public String status; // "Success", "Error", "Pending"
  @AuraEnabled
  public String statusMessage;

  public AIProductSummaryResult() {
    positioningBullets = new List<String>();
    decodedTerms = new Map<String, String>();
    warnings = new List<String>();
  }
}
