@isTest
private class TimeAndBillingMonthlySpec {
  @isTest
  static void testTimeAndBillingMonthly() {    
    Test.StartTest();
    TimeAndBillingMonthly sh1 = new TimeAndBillingMonthly();

    String sch = '0 0 23 * * ?'; system.schedule('Test time and billing monthly', sch, sh1); 
    Test.stopTest(); 
  }
}