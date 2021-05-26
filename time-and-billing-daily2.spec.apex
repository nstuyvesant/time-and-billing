@isTest
private class TimeAndBillingDaily2Spec {

  @isTest
  private static void testTimeAndBillingDaily2() {

    Test.startTest();
    String CRON_EXP = '0 0 0 3 9 ? 2022';
    String jobId = System.schedule('testBasicScheduledApex',
      CRON_EXP, 
      new TimeAndBillingDaily2()
    );
    Test.stopTest();
  }
}