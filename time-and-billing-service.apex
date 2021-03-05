@RestResource(urlMapping='/issue/*')
global with sharing class TimeAndBillingService {
  
  @HttpPut
  global static void doPut(String billingType, String accountName, String subject, String issueType) {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;

    String issueKey = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
    
    if (issueKey == null || issueKey == '') {
      res.statusCode = 400;
      return;
    }
      
    // Get Account.Id for named customer
    List<Account> customers = [SELECT Id FROM Account WHERE Name = :accountName LIMIT 1];
    if (customers.size() == 0) {
      res.statusCode = 404;
      return;
    }
    ID accountId = customers[0].Id;

    // Find Time Entries for this Jira Issue
    List<Time_Entry__c> timeEntries = [
      SELECT
        Account__c, Resource__c, Activity__c, Role__c, Date_Worked__c,
        Hours__c, Jira_Issue__c, Notes__c, Worklog_ID__c, Hourly_Rate__c,
        Hourly_Cost__c, Billed__c, Billing__c, Entitlement__c, Subject__c, Type__c
      FROM Time_Entry__c
      WHERE Jira_Issue__c = :issueKey And Worklog_ID__c != null
    ];

    // Setup empty list of Time Entries for any reversals needed
    List<Time_Entry__c> reversedTimeEntries = new List<Time_Entry__c>();

    // Loop through Time Entries for this Jira Issue
    for (Time_Entry__c timeEntry: timeEntries) {
      // Billed Time Entries must be reversed if new Billing value is not 'Hourly'
      if (timeEntry.Billed__c && billingType != 'Hourly') {
        // Create reverse time entry
        Time_Entry__c reversedTimeEntry = new Time_Entry__c(
          Worklog_ID__c = - timeEntry.Worklog_ID__c, // negative ID so we know easily which one was reversed
          Account__c = timeEntry.Account__c,
          Resource__c = timeEntry.Resource__c,
          Activity__c = timeEntry.Activity__c,
          Role__c = timeEntry.Role__c,
          Date_Worked__c = timeEntry.Date_Worked__c,
          Hours__c = - timeEntry.Hours__c, // negative hours
          Hourly_Rate__c = timeEntry.Hourly_Rate__c,
          Hourly_Cost__c = timeEntry.Hourly_Cost__c,
          Billed__c = false,
          Billing__c = timeEntry.Billing__c,
          Jira_Issue__c = timeEntry.Jira_Issue__c,
          Notes__c = timeEntry.Notes__c,
          Entitlement__c = null
        );
        // Add it to the list of upserts (upsert in case we do this multiple times)
        reversedTimeEntries.add(reversedTimeEntry);
      }

      // Original gets the updated values
      timeEntry.Billing__c = billingType;
      timeEntry.Billed__c = false;
      timeEntry.Subject__c = subject;
      timeEntry.Type__c = issueType;
      timeEntry.Account__c = accountId;
    }
    
    System.debug(timeEntries);
    update timeEntries;

    System.debug(reversedTimeEntries);
    upsert reversedTimeEntries Worklog_ID__c;

    res.statusCode = 204; // Successfully updated
  }
}