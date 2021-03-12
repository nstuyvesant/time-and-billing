@isTest 
private class TimeAndBillingServiceSpec {

  @isTest
  private static void testPutHourly() {
    System.debug('TEST - PUT /issue/{issueKey} with billingType = Hourly expecting success');
    TimeAndBillingDataGenerator.createTestData();
    
    Time_Entry__c timeEntry = [SELECT Id, Account__c, Opportunity__c, Jira_Issue__c FROM Time_Entry__c WHERE Jira_Issue__c = 'PS-001' LIMIT 1][0];
    Account a = [SELECT Id, Name FROM Account WHERE Id = :timeEntry.Account__c LIMIT 1][0];
    Opportunity opp = [SELECT Id FROM Opportunity WHERE Billing__c = 'Hourly' LIMIT 1][0];

    // Setup request with JSON body
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestURI = '/issue/' + timeEntry.Jira_Issue__c;
    req.httpMethod = 'PUT';
    RestContext.request = req;
    req.requestBody = Blob.valueOf('{"billingType": "Hourly", "accountName":"' + a.Name + '", "subject":"Test subject", "issueType":"Story", "opportunityUrl":"https://utilant.lightning.force.com/lightning/r/' + opp.Id + '/view"}');
    RestContext.response = res;

    Test.startTest();
    TimeAndBillingService.doPut('Hourly', a.Name, 'Test subject', 'Story', 'https://utilant.lightning.force.com/lightning/r/' + opp.Id + '/view');
    System.assertEquals(res.statusCode, 204);
    Test.stopTest();
  }

    
  @isTest
  private static void testPutSubscription() {
    System.debug('TEST - PUT /issue/{issueKey} with billingType = Subscription (Enhancement) expecting success');
    TimeAndBillingDataGenerator.createTestData(); 
    
    Time_Entry__c timeEntry = [SELECT Id, Account__c, Opportunity__c, Jira_Issue__c FROM Time_Entry__c WHERE Jira_Issue__c = 'PS-001' LIMIT 1][0];
    Account a = [SELECT Id, Name FROM Account WHERE Id = :timeEntry.Account__c LIMIT 1][0];
    Opportunity opp = [SELECT Id FROM Opportunity WHERE Billing__c = 'Hourly' LIMIT 1][0];

    // Setup request with JSON body
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestURI = '/issue/' + timeEntry.Jira_Issue__c;
    req.httpMethod = 'PUT';
    RestContext.request = req;
    req.requestBody = Blob.valueOf('{"billingType": "Subscription (Enhancement)", "accountName":"' + a.Name + '", "subject":"Test subject", "issueType":"Story", "opportunityUrl":"https://utilant.lightning.force.com/lightning/r/' + opp.Id + '/view"}');
    RestContext.response = res;

    Test.startTest();
    TimeAndBillingService.doPut('Subscription (Enhancement)', a.Name, 'Test subject', 'Story', 'https://utilant.lightning.force.com/lightning/r/' + opp.Id + '/view');
    System.assertEquals(res.statusCode, 204);
    Test.stopTest();
  }


  @isTest
  private static void testPutMissingIssue() {
    System.debug('TEST - PUT /issue/ without issueKey expecting failure');
    TimeAndBillingDataGenerator.createTestData();

    Time_Entry__c timeEntry = [SELECT Id, Account__c, Opportunity__c, Jira_Issue__c FROM Time_Entry__c WHERE Jira_Issue__c = 'PS-001' LIMIT 1][0];
    Account a = [SELECT Id, Name FROM Account WHERE Id = :timeEntry.Account__c LIMIT 1][0];
    Opportunity opp = [SELECT Id FROM Opportunity WHERE Billing__c = 'Hourly' LIMIT 1][0];

    // Run request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestURI = '/issue/'; // Note: Jira Issue key not supplied
    req.httpMethod = 'PUT';

    RestContext.request = req;
    req.requestBody = Blob.valueOf('{"billingType": "Subscription (Enhancement)", "accountName":"' + a.Name + '", "subject":"Test subject", "issueType":"Story", "opportunityUrl":"https://utilant.lightning.force.com/lightning/r/0061U00000GI8XcQAL/view"}');
    RestContext.response = res;

    Test.startTest();
    TimeAndBillingService.doPut('Subscription (Enhancement)', a.Name, 'Test subject', 'Story', 'https://utilant.lightning.force.com/lightning/r/0061U00000GI8XcQAL/view');
    Test.stopTest();
    System.assertEquals(res.statusCode, 400);
  }
}