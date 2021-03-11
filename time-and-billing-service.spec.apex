@isTest 
private class TimeAndBillingServiceSpec {

  @isTest
  private static void callDoPutWithIssue() {
    // TODO: Create Opportunity in TimeAndBillingDataGenerator.createTestData()
    TimeAndBillingDataGenerator.createTestData();    
    // Prepare test data
    Account a = [SELECT Id, Name FROM Account WHERE Type = 'Customer' AND Platform__c = 'Carrier' LIMIT 1][0];
    Contact c = [SELECT Id FROM Contact WHERE Account.Name = 'Utilant, LLC' LIMIT 1][0];

    Time_Entry__c te = new Time_Entry__c(
      Jira_Issue__c = 'PS-12t',
      Account__c = a.Id,
      Worklog_ID__c = 59999,
      Resource__c = c.id,
      Activity__c = 'Development',
      Billed__c = true,
      Role__c = 'Executive',
      Notes__c = 'Does updated on the issue get revised when a worklog is added?',
      Hours__c = 1,
      Hourly_Rate__c = 0,
      Date_Worked__c = Date.Today().addDays(-20),
      Hourly_Cost__c = 100,
      Billing__c = 'None'
    );
    insert te;

    // Run Request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestURI = '/issue/PS-12t';
    req.httpMethod = 'PUT';
    RestContext.request = req;
    req.requestBody = Blob.valueOf('{"billingType": "Subscription (Enhancement)", "accountName":"' + a.Name + '", "subject":"Test subject", "issueType":"Story", "opportunityUrl":"https://utilant.lightning.force.com/lightning/r/0061U00000GI8XcQAL/view"}');
    RestContext.response= res;
    System.debug('1: ' + res.statusCode);
    Test.startTest();
    TimeAndBillingService.doPut('Subscription (Enhancement)', a.Name, 'Test subject', 'Story', 'https://utilant.lightning.force.com/lightning/r/0061U00000GI8XcQAL/view');
    System.assertEquals(res.statusCode, 204);
    Test.stopTest();
  }

  @isTest
  private static void callDoPutWithoutIssue() {
    TimeAndBillingDataGenerator.createTestData();
    // Prepare test data
    Account a = [SELECT Id, Name FROM Account WHERE Type = 'Customer' AND Platform__c = 'Carrier' LIMIT 1][0];
    Contact c = [SELECT Id FROM Contact WHERE Account.Name = 'Utilant, LLC' LIMIT 1][0];

    Time_Entry__c te = new Time_Entry__c(
      Jira_Issue__c = 'PS-12t',
      Account__c = a.Id,
      Worklog_ID__c = 59999,
      Resource__c = c.id,
      Activity__c = 'Development',
      Billed__c = true,
      Role__c = 'Executive',
      Notes__c = 'Does updated on the issue get revised when a worklog is added?',
      Hours__c = 1,
      Hourly_Rate__c = 0,
      Date_Worked__c = Date.Today().addDays(-20),
      Hourly_Cost__c = 100,
      Billing__c = 'None'
    );
    insert te;

    // Run request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestURI = '/issue/';
    req.httpMethod = 'PUT';

    RestContext.request = req;
    req.requestBody = Blob.valueOf('{"billingType": "Subscription (Enhancement)", "accountName":"' + a.Name + '", "subject":"Test subject", "issueType":"Story", "opportunityUrl":"https://utilant.lightning.force.com/lightning/r/0061U00000GI8XcQAL/view"}');
    RestContext.response= res;

    Test.startTest();
    TimeAndBillingService.doPut('Subscription (Enhancement)', a.Name, 'Test subject', 'Story', 'https://utilant.lightning.force.com/lightning/r/0061U00000GI8XcQAL/view');
    System.assertEquals(res.statusCode, 400);
    Test.stopTest();
  }
}