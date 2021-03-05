@isTest
private class TimeAndBillingSpec {

  private static final String COMPANY = 'Utilant, LLC';
  private static final DateTime SYNC_DATE = System.today().addDays(-1);
  private static final String SYNC_DATE_STRING = SYNC_DATE.format('yyyy-MM-dd', 'GMT');
  private static final Date INVOICE_DATE = Date.today().toStartOfMonth().addDays(-1); // Last day of prior month

  /*
    Coverage gaps:
      getCompanyId(): when COMPANY_ACCOUNT_NAME does not exist
  */

  // Test syncTempoToSalesforce()
  // Coverage gaps:
  //   HTTP Error handler for tempoApi() - 2 lines
  //   getAccountsFromTempo() when status code != 200 - 3 lines
  //   getIssueFieldsFromJira() when status code != 200 - 5 lines
  //   reverseBilledTimeEntries() - need to stage time entry that was billed - 10 lines
  //   workLogsToTimeEntries()
  //     if user is null because worklog.author.accountId wasn't in userMap from Jira - 3 lines
  //     if account is null because there was no Salesforce Account matching one from Tempo - 3 lines
  //     customer does not have rate card - 1 line
  //     Company does not have rate card - line
  //     Customer is on subscription and time entry is from Account Manager or Technical Support - 2 lines
  //   upsertWorklogsToSalesforce() - error-handler for upsert - 3 lines

  private static void setupTempoMocks(Integer responseCode, String status) {
    TimeAndBillingDataGenerator.createTestData();

    // Get list of accounts generated and create JSON for Tempo /accounts response
    List<Account> accounts = [SELECT Id, Name FROM Account WHERE Type = 'Customer' AND Platform__c != null ORDER BY Name];
    String accountsAsJson = '{"metadata":{"count":' + String.valueOf(accounts.size()) + '},"results":[';
    for (Account thisAccount: accounts) {
      accountsAsJson += '{"key":"' + String.valueOf(thisAccount.Id) + '", "name":"' + thisAccount.Name + '","leadAccountId":"' + JIRA_USER_ID + '","status":"OPEN","global":true},';
    }
    accountsAsJson = accountsAsJson.removeEnd(',') + ']}';

    // Get list of resources generated and create JSON for Jira /users response
    List<Contact> resources = [SELECT Id, FirstName, LastName, Email FROM Contact ORDER BY LastName,FirstName];
    String jiraUsersAsJson = '[';
    for (Contact resource: resources) {
      jiraUsersAsJson += '{"accountId":"' + resource.Id + '","displayName":"' + resource.FirstName + ' ' + resource.LastName + '","emailAddress":"' + resource.Email + '","active":true},';
    }
    jiraUsersAsJson = jiraUsersAsJson.removeEnd(',') + ']';

    // getAccountsFromTempo() - /accounts
    SingleRequestMock getAccountsResponse = new SingleRequestMock(responseCode, status,
      responseCode == 200 ? accountsAsJson : '{}',
      null);

    // getUsersMapFromJira() - /users/search?maxResults=1000
    SingleRequestMock getJiraUsersResponse = new SingleRequestMock(responseCode, status,
      responseCode == 200 ? jiraUsersAsJson : '{}',
      null);

	// resources = Jane Doe, John Doe, Trudy Example, Dennis Sample
	// accounts = ?
    String tempoWorklogsAsJson = '{"metadata":{"count":4,"offset":0,"limit":50},"results":[';
    tempoWorklogsAsJson += '{"tempoWorklogId":33,"issue":{"key":"PS-001","id":1},"timeSpentSeconds":3600,"startDate":"2021-01-20","description":"Test Story","createdAt":"2021-01-22T20:47:14Z","updatedAt":"2021-01-22T18:48:42Z","author":{"accountId":"' + String.valueOf(resources[0].Id) + '","displayName":"' + resources[0].FirstName + ' ' + resources[0].LastName + '"},"attributes":{"values":[{"key":"_Account_","value":"' + String.valueOf(accounts[0].Id) + '"},{"key":"_Activity_","value":"Planning"}] }},';
    tempoWorklogsAsJson += '{"tempoWorklogId":34,"issue":{"key":"PS-002","id":2},"timeSpentSeconds":4000,"startDate":"2021-01-21","description":"Test Bug","createdAt":"2021-01-22T20:47:14Z","updatedAt":"2021-01-22T18:48:42Z","author":{"accountId":"' + String.valueOf(resources[1].Id) + '","displayName":"' + resources[1].FirstName + ' ' + resources[1].LastName + '"},"attributes":{"values":[{"key":"_Account_","value":"' + String.valueOf(accounts[1].Id) + '"},{"key":"_Activity_","value":"DefectResolution"}] }},';
    tempoWorklogsAsJson += '{"tempoWorklogId":35,"issue":{"key":"VEN-001","id":3},"timeSpentSeconds":5000,"startDate":"2021-01-22","description":"Test Task","createdAt":"2021-01-22T20:47:14Z","updatedAt":"2021-01-22T18:48:42Z","author":{"accountId":"' + String.valueOf(resources[2].Id) + '","displayName":"' + resources[2].FirstName + ' ' + resources[2].LastName + '"},"attributes":{"values":[{"key":"_Account_","value":"' + String.valueOf(accounts[2].Id) + '"},{"key":"_Activity_","value":"Development"}] }},';
    tempoWorklogsAsJson += '{"tempoWorklogId":26,"issue":{"key":"VEN-002","id":4},"timeSpentSeconds":6000,"startDate":"2021-01-23","description":"Test Epic","createdAt":"2021-01-22T20:47:14Z","updatedAt":"2021-01-22T18:48:42Z","author":{"accountId":"' + String.valueOf(resources[0].Id) + '","displayName":"' + resources[3].FirstName + ' ' + resources[3].LastName + '"},"attributes":{"values":[{"key":"_Account_","value":"' + String.valueOf(accounts[3].Id) + '"},{"key":"_Activity_","value":"Testing"}] }}';
    tempoWorklogsAsJson += ']}';
    // TODO: resources[3] has a null Billing Role but it causes an error (and should skip import gracefully)

    // getWorklogsFromTempo() - '/worklogs?limit=1000&offset=' + String.valueOf(offset) + '&updatedFrom=' + syncDate.format('yyyy-MM-dd', 'GMT');
    SingleRequestMock getWorklogsResponse = new SingleRequestMock(responseCode, status,
      responseCode == 200 ? tempoWorklogsAsJson : '{}',
      null);

    String jiraIssueFieldsAsJson = '{"startAt":0,"maxResults":50,"total":4,"issues":[';
    jiraIssueFieldsAsJson += '{"id":"1","key":"PS-001","fields":{"summary":"Test Story","issuetype":{"name":"Story"},"customfield_10090":{"value":"Hourly"}}},';
    jiraIssueFieldsAsJson += '{"id":"2","key":"PS-002","fields":{"summary":"Test Bug","issuetype":{"name":"Bug"},"customfield_10090":{"value":"None"}}},';
    jiraIssueFieldsAsJson += '{"id":"3","key":"VEN-001","fields":{"summary":"Test Task","issuetype":{"name":"Task"},"customfield_10090":{"value":"Fixed-Rate"}}},';
    jiraIssueFieldsAsJson += '{"id":"4","key":"VEN-002","fields":{"summary":"Test Epic","issuetype":{"name":"Epic"},"customfield_10090":{"value":"Hourly"}}}';
    jiraIssueFieldsAsJson += ']}';
    
    // getIssueFieldsFromJira() - /search with POST
    SingleRequestMock postResponseSearch = new SingleRequestMock(responseCode, status,
      responseCode == 200 ? jiraIssueFieldsAsJson : '{}',
      null);

    Map<String,HttpCalloutMock> httpResponseMap = new Map<String,HttpCalloutMock>();
    httpResponseMap.put('callout:Tempo/core/3/worklogs?limit=1000&offset=0&updatedFrom=' + SYNC_DATE_STRING, getWorklogsResponse);
    httpResponseMap.put('callout:Jira/rest/api/3/users/search?maxResults=1000', getJiraUsersResponse);
    httpResponseMap.put('callout:Jira/rest/api/3/search', postResponseSearch);
    httpResponseMap.put('callout:Tempo/core/3/accounts', getAccountsResponse);
    HttpCalloutMock multiCalloutMock = new MultiRequestMock(httpResponseMap);
    Test.setMock(HttpCalloutMock.class, multiCalloutMock);
  }


  @isTest static void testSyncTempoToSalesforce200() {
    System.debug('TESTING TimeAndBilling.syncTempoToSalesforce() with mocked HTTP 200 responses from Tempo.');
    setupTempoMocks(200, 'OK');

    // Wrap asynchronous call
    Test.startTest();
    TimeAndBilling.syncTempoToSalesforce(SYNC_DATE);
    Test.stopTest();
  }

  @isTest static void testSyncTempoToSalesforce502() {
    System.debug('TESTING TimeAndBilling.syncTempoToSalesforce() with mocked HTTP 502 responses from Tempo.');
    setupTempoMocks(502, 'Bad Gateway');

    // Wrap asynchronous call
    Test.startTest();
    TimeAndBilling.syncTempoToSalesforce(SYNC_DATE);
    Test.stopTest();
  }


  // Test syncTimeEntryDeletions()
  // Coverage gaps:
  //   getTempoDeletedWorklogs() when status != 200 - 2 lines

  @isTest static void testSyncTimeEntryDeletions() {
    System.debug('TESTING TimeAndBilling.syncTimeEntryDeletions() with mocked HTTP 200 responses from Tempo.');
    String iso8601 = SYNC_DATE_STRING + 'T00:00:00.000Z';
    // Mock responses
    SingleRequestMock getResponse = new SingleRequestMock(200, 'OK',
      '{"metadata":{"limit":1000,"count":3},"results":[{"deletedAt":"2021-02-22T14:41:53.189000","tempoWorklogId":"16013","jiraWorklogId":"26024"},{"deletedAt":"2021-02-22T18:26:51.124000","tempoWorklogId":"16085","jiraWorklogId":"26096"},{"deletedAt":"2021-02-22T18:47:31.745000","tempoWorklogId":"16130","jiraWorklogId":"26141"}]}',
      null);
    Map<String,HttpCalloutMock> httpResponseMap = new Map<String,HttpCalloutMock>();
    httpResponseMap.put('callout:Tempo/audit/1/events/deleted/types/worklog?limit=1000&updatedFrom=' + iso8601, getResponse);
    HttpCalloutMock multiCalloutMock = new MultiRequestMock(httpResponseMap);
    Test.setMock(HttpCalloutMock.class, multiCalloutMock);

    // Wrap asynchronous call
    Test.startTest();
    TimeAndBilling.syncTimeEntryDeletions(SYNC_DATE);
    Test.stopTest();
  }


  // Test syncSalesforceAccountsToTempo()
  // Coverage gaps:
  //   getAccountsFromTempo() when status != 200 - 3 lines
  //   syncAccountToTempo() when status != 200 or 204 - 1 line

  private static final String JIRA_USER_NAME = 'Jane Doe';
  private static final String JIRA_USER_ID = '5cfa66cbd9f6b90f3d4b2f87';
  private static final String JIRA_USER_EMAIL = 'jane.doe@test.com';
  private static final SingleRequestMock JIRA_USER_GET = new SingleRequestMock(200, 'OK',
    '[{"accountId":"' + JIRA_USER_ID + '","emailAddress": "' + JIRA_USER_EMAIL + '","displayName":"' + JIRA_USER_NAME + '","active":true}]',
    null
  );


  // Test syncZendeskToSalesforce()
  // Coverage gaps:
  //   getSolvedTicketsFromZendesk() when status code != 200 - 5 lines
  //   getOrganizationsFromZendesk() when status code != 200 - 1 line
  //   syncZendeskToSalesforce() when customer is not on subscription and there is no company rate

  private static void setupZendeskMocks(Integer responseCode, String status) {
    // getAgentEmailsFromZendesk() - /users.json?role[]=admin&role[]=agent - one assignee not in Contacts
    SingleRequestMock getAgentEmailsResponse = new SingleRequestMock(responseCode, status,
      responseCode == 200 ? '{"users":[{"id":370976246333,"name":"Dennis Sample","email":"dennis.sample@test.com"},{"id":399513725134,"name":"Trudy Example","email":"trudy.example@test.com"},{"id":399513725100,"name":"Zaphod Beeblebrox","email":"not.found@test.com"}],"next_page":null,"previous_page":null,"count":3}':'{}',
      null);
    // getOrganizationsFromZendesk() - /search.json?query=type:organization
    SingleRequestMock getOrganizationsResponse = new SingleRequestMock(responseCode, status,
      responseCode == 200 ? '{"results":[ {"id":370270598734,"name":"Test Non-Subscription Carrier"}, {"id":370270598735,"name":"Test Subscription Carrier"} ],"next_page":"https://utilant.zendesk.com/api/v2/search.json?page=2&query=type%3Aorganization","previous_page":null,"count":2}': '{}',
      null);
    SingleRequestMock getOrganizationsPage2Response = new SingleRequestMock(responseCode, status,
      responseCode == 200 ? '{"results":[ {"id":370270598736,"name":"Test Subscription Vendor"}, {"id":370270598737,"name":"Test Non-Subscription Vendor"} , {"id":370270598738,"name":"Test Non-Subscription Rack Rate Vendor"} ],"next_page":null,"previous_page":"https://utilant.zendesk.com/api/v2/search.json?page=1&query=type%3Aorganization","count":3}': '{}',
      null);
    // getSolvedTicketsFromZendesk() - /search.json?query=type:ticket solved>=SYNC_DATE
    SingleRequestMock getSolvedTicketsResponse = new SingleRequestMock(responseCode, status,
      responseCode == 200 ? '{ "results":[ {"id":1,"type":"question","subject":"Test question","status":"solved","assignee_id":370976246333,"organization_id":370270598734,"updated_at":"2021-01-03T12:00:00Z","custom_fields":[{"id": 360030708654,"value":3600},{"id":360030745593,"value":"Question"}]}, {"id":2,"type":"problem","subject":"Test problem","status":"solved","assignee_id":399513725134,"organization_id":370270598737,"updated_at":"2021-01-03T14:00:00Z","custom_fields":[{"id":360030708654,"value":7200},{"id":360030745593,"value":"Problem"}]}, {"id":3,"type":"problem","subject":"Test Defect","status":"solved","assignee_id":399513725134,"organization_id":370270598737,"updated_at":"2021-01-03T14:00:00Z","custom_fields":[{"id":360030708654,"value":7200 },{"id":360030745593,"value":"Defect"}]}, {"id":4,"type":"incident","subject":"Test incident","status":"solved","assignee_id":399513725100,"organization_id":370270598735,"updated_at":"2021-01-03T14:00:00Z","custom_fields":[{"id":360030708654,"value":1200},{"id":360030745593,"value":"Incident"}]}, {"id":5,"type":"question","subject":"Test question","status":"solved","assignee_id":399513725134,"organization_id":370270598738,"updated_at":"2021-01-03T12:00:00Z","custom_fields":[{"id": 360030708654,"value":3600},{"id":360030745593,"value":"Question"}]} ], "next_page":null,"previous_page":null,"count":5}' : '{}',
      null);

    Map<String,HttpCalloutMock> httpResponseMap = new Map<String,HttpCalloutMock>();
    httpResponseMap.put('callout:Zendesk/api/v2/users.json?role[]=admin&role[]=agent', getAgentEmailsResponse);
    httpResponseMap.put('callout:Zendesk/api/v2/search.json?query=type:organization', getOrganizationsResponse);
    httpResponseMap.put('callout:Zendesk/api/v2/search.json?page=2&query=type%3Aorganization', getOrganizationsPage2Response);
    httpResponseMap.put('callout:Zendesk/api/v2/search.json?query=type%3Aticket+solved%3E%3D' + SYNC_DATE_STRING, getSolvedTicketsResponse);
    HttpCalloutMock multiCalloutMock = new MultiRequestMock(httpResponseMap);
    Test.setMock(HttpCalloutMock.class, multiCalloutMock);
  }

  @isTest static void testSyncZendeskToSalesforce200() {
    System.debug('TESTING TimeAndBilling.syncZendeskToSalesforce() with mocked HTTP 200 responses from Zendesk.');
    TimeAndBillingDataGenerator.createTestData();
    setupZendeskMocks(200, 'OK');

    // Wrap asynchronous call
    Test.startTest();
    TimeAndBilling.syncZendeskToSalesforce(SYNC_DATE);
    Test.stopTest();

    // TODO: Assert number of Time Entries increased by 1 (one was ignored because of missing Billing Role on Contact)
    // TODO: Assert number of Time Billing Audit records increased by 2?
  }

  @isTest static void testSyncZendeskToSalesforce502() {
    System.debug('TESTING TimeAndBilling.syncZendeskToSalesforce() with mocked HTTP 502 responses from Zendesk.');
    TimeAndBillingDataGenerator.createTestData();
    setupZendeskMocks(502, 'Bad Gateway');

    // Wrap asynchronous call
    Test.startTest();
    TimeAndBilling.syncZendeskToSalesforce(SYNC_DATE);
    Test.stopTest();

    // TODO: Assert number of Time Entries did not increase
    // TODO: Assert number of Time Billing Audit records increased by 1?
  }

    
  // Test syncSalesforceAccountsToTempo()
  // Coverage gaps:
  //   syncSalesforceAccountsToTempo() - error-handler for upserting to Tempo - 3 lines

  private static Account createCustomer(String customerName) {
    Account customer = new Account(
      Name = customerName,
      Type = 'Customer',
      Platform__c = 'Carrier',
      Not_on_subscription__c = false,
      c2g__CODASalesTaxStatus__c = 'Exempt for Qualifying Products'
    );
    insert customer;
    return customer;
  }


  // Test scenario where no Tempo Accounts are created or updated
  @isTest static void testSalesforceAccountsToTempoNoChange() {
    System.debug('TESTING TimeAndBilling.syncSalesforceAccountsToTempo() with mocked HTTP 200 responses from Tempo when there are no changes.');
    Account customer = createCustomer('Test Subscription Carrier');

    // Mock responses
    // Return data matches customer and Jira User constants - GET "https://api.tempo.io/core/3/accounts"
    SingleRequestMock getResponseWithOneAccount = new SingleRequestMock(200, 'OK',
      '{"metadata":{"count":1},"results":[{"key":"' + customer.Id + '","name":"' + customer.Name + '","status":"OPEN","global":true,"leadAccountId":"' + JIRA_USER_ID + '"}]}',
      null);
    Map<String,HttpCalloutMock> httpResponseMap = new Map<String,HttpCalloutMock>();
    httpResponseMap.put('callout:Tempo/core/3/accounts', getResponseWithOneAccount);
    httpResponseMap.put('callout:Jira/rest/api/3/users/search?maxResults=1000', JIRA_USER_GET);
    HttpCalloutMock multiCalloutMock = new MultiRequestMock(httpResponseMap);
    Test.setMock(HttpCalloutMock.class, multiCalloutMock);

    // Wrap asynchronous call
    Test.startTest();
    TimeAndBilling.syncSalesforceAccountsToTempo();
    Test.stopTest();
  }


  // Test creation of new Tempo Account (POST - 200)
  @isTest static void testSalesforceAccountsToTempoPost() {
    System.debug('TESTING TimeAndBilling.syncSalesforceAccountsToTempo() with mocked HTTP 200 responses from Tempo when there is a new account.');
    Account customer = createCustomer('Test Subscription Carrier');

    // Return data matches Account and Jira User above - GET and POST "https://api.tempo.io/core/3/accounts"
    SingleRequestMock getAndPostResponse = new SingleRequestMock(200, 'OK',
      '{"self":"https://api.tempo.io/core/3/accounts","metadata":{"count":0},"results":[]}',
      null);
    Map<String,HttpCalloutMock> httpResponseMap = new Map<String,HttpCalloutMock>();
    httpResponseMap.put('callout:Tempo/core/3/accounts', getAndPostResponse);
    httpResponseMap.put('callout:Jira/rest/api/3/users/search?maxResults=1000', JIRA_USER_GET);
    HttpCalloutMock multiCalloutMock = new MultiRequestMock(httpResponseMap);
    Test.setMock(HttpCalloutMock.class, multiCalloutMock);

    // Wrap asynchronous call
    Test.startTest();
    TimeAndBilling.syncSalesforceAccountsToTempo();
    Test.stopTest();
  }


  // Test updating existing Tempo Account (PUT - 204)
  @isTest static void testSalesforceAccountsToTempoPut() {
    System.debug('TESTING TimeAndBilling.syncSalesforceAccountsToTempo() with mocked HTTP 200 responses from Tempo when there is an account with a changed name.');
    Account customer = createCustomer('Test Subscription Carrier');

    // Added "OLD" in front of customer name so it must be updated to new name
    SingleRequestMock getResponseWithOneAccount = new SingleRequestMock(200, 'OK',
      '{"self":"https://api.tempo.io/core/3/accounts","metadata":{"count":1},"results":[{"key":"' + customer.Id + '","name":"OLD ' + customer.Name + '","status":"OPEN","global":true,"leadAccountId":"' + JIRA_USER_ID + '"}]}',
      null);

    Map<String,HttpCalloutMock> httpResponseMap = new Map<String,HttpCalloutMock>();
    httpResponseMap.put('callout:Tempo/core/3/accounts', getResponseWithOneAccount);
    httpResponseMap.put('callout:Jira/rest/api/3/users/search?maxResults=1000', JIRA_USER_GET);
    HttpCalloutMock multiCalloutMock = new MultiRequestMock(httpResponseMap);
    Test.setMock(HttpCalloutMock.class, multiCalloutMock);

    // Wrap asynchronous call
    Test.startTest();
    TimeAndBilling.syncSalesforceAccountsToTempo();
    Test.stopTest();
  }
    
    
  // Test timeEntryToOpportunity()
  @isTest static void timeEntryToOpportunity() {
    System.debug('TESTING TimeAndBilling.timeEntryToOpportunity().');
      
    Date fromDate = date.newInstance(2021, 1, 1);
    Date toDate = date.newInstance(2021, 1, 31);

    // Wrap asynchronous call
    Test.startTest();
	  TimeAndBilling.timeEntryToOpportunity(fromDate, toDate);
    Test.stopTest();
  }

  // Test generateHourlyInvoices()
  // Coverage gaps:
  //   getCurrentEntitlement() - null entitlement that cannot be reached - 1 line
    
  // Verify invoices generate under various scenarios dictated by data generator
  @isTest(SeeAllData=true) static void testHourlyInvoiceGeneration() {
    System.debug('TESTING TimeAndBilling.generateHourlyInvoices() for Vendors and Carriers.');
    // Prep test data
    TimeAndBillingDataGenerator.createTestData();

    // Get counts before running the test
    Integer salesInvoicesBefore = [SELECT Id FROM c2g__codaInvoice__c WHERE c2g__InvoiceDate__c = :INVOICE_DATE].size();
    Integer timeEntriesBefore = [SELECT Id FROM Time_Entry__c WHERE Billed__c = true].size();

    // Wrap asynchronous call
    Test.startTest();
    TimeAndBilling.generateHourlyInvoices(INVOICE_DATE, 'Vendor');
    TimeAndBilling.generateHourlyInvoices(INVOICE_DATE, 'Carrier');
    Test.stopTest();

    // Sales Invoices should have been created
    Integer salesInvoicesAfter = [SELECT id FROM c2g__codaInvoice__c WHERE c2g__InvoiceDate__c = :INVOICE_DATE].size();
    System.assert(salesInvoicesAfter > salesInvoicesBefore, 'No Sales Invoices were created.');

    // Additional Time Entries should have Billed__c = true;
    Integer timeEntriesAfter = [SELECT Id FROM Time_Entry__c WHERE Billed__c = true].size();
    System.assert(timeEntriesAfter > timeEntriesBefore, 'No Time Entries were marked billed.');
  }


  // Verify no errors if hourly invoice generation run when no time entries to bill
  @isTest(SeeAllData=true) static void testHourlyInvoiceGenerationNoTimeEntries() {
    System.debug('TESTING TimeAndBilling.generateHourlyInvoices() for Vendors and Carriers when there are no time entries.');

    // Get count before running test
    Integer salesInvoicesBefore = [SELECT Id FROM c2g__codaInvoice__c WHERE c2g__InvoiceDate__c = :INVOICE_DATE].size();

    // Mark all hourly time entries billed so there's nothing to bill
    List<Time_Entry__c> timeEntries = [SELECT Id, Billed__c FROM Time_Entry__c WHERE Billing__c = 'Hourly' AND Billed__c = false];
    for (Time_Entry__c timeEntry: timeEntries) {
      timeEntry.Billed__c = true;
    }
    update timeEntries;

    // Wrap asynchronous call
    Test.startTest();
    TimeAndBilling.generateHourlyInvoices(INVOICE_DATE, 'Vendor');
    TimeAndBilling.generateHourlyInvoices(INVOICE_DATE, 'Carrier');
    Test.stopTest();

    // Sales Invoices should have not been created
    Integer salesInvoicesAfter = [SELECT id FROM c2g__codaInvoice__c WHERE c2g__InvoiceDate__c = :INVOICE_DATE].size();
    System.assert(salesInvoicesAfter == salesInvoicesBefore, 'Sales Invoices were created.');

    // TODO: Assert Entitlement Hours Used increased
  }
}