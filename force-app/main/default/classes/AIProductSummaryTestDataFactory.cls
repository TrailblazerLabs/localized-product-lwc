@IsTest
public class AIProductSummaryTestDataFactory {
  public static Product2 createProduct() {
    return new Product2(
      Id = productId(),
      Name = 'Localized Product Test',
      ProductCode = 'LOCAL-TEST',
      Description = 'A test product for localized AI summaries.',
      IsActive = true
    );
  }

  public static Id productId() {
    String keyPrefix = Product2.SObjectType.getDescribe(
        SObjectDescribeOptions.DEFERRED
      )
      .getKeyPrefix();
    return Id.valueOf(keyPrefix + '000000000000');
  }
}
