@isTest
private class TimeAndBillingTempoUpsertSpec {
  @testSetup
  static void setup() {}


  @isTest static void test() {
    List<Time_Entry__c> timeEntries = new List<Time_Entry__c>();
    // Insert 10 Time Entries
    for (Integer i=0; i<10; i++) {
      timeEntries.add(new Time_Entry__c(
        Billed__c = false,
        Worklog_ID__c = 10000 + i,
        Resource__c = (ID) '0031U00001PZWRvQAP',
        Account__c = (ID) '0011U00000rZRzpQAG',
        Activity__c = 'TimeOff',
        Role__c = 'Developer',
        Date_Worked__c = Date.newInstance(2021, 1, 15),
        Hours__c = i,
        Hourly_Rate__c = 200,
        Hourly_Cost__c = 59,
        Billing__c = 'None',
        Jira_Issue__c = 'UT-1',
        Notes__c = 'Unit test for batch',
        Type__c = 'Task',
        Subject__c = 'Paid Time-Off'
      ));
    }
    Test.startTest();
    TimeAndBillingTempoUpsert timeEntriesBatch = new TimeAndBillingTempoUpsert(timeEntries);
    Id batchId = Database.executeBatch(timeEntriesBatch);
    Test.stopTest();
    // after the testing stops, assert records were updated properly
    System.assertEquals(10, [SELECT count() FROM Time_Entry__c WHERE Role__c = 'Developer']);
  }
}