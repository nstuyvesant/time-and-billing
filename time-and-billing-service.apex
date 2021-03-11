@RestResource(urlMapping='/issue/*')
global with sharing class TimeAndBillingService {
  
  private static ID getSalesforceId(String url) {
    if (url == null) return null;
    Pattern urlPattern = Pattern.compile('.*/lightning/r.*/([a-zA-Z0-9]{15,18})/view');
    Matcher urlMatcher = urlPattern.matcher(url);
    return urlMatcher.matches() ? (ID) urlMatcher.group(1) : null;
  }


  @HttpPut
  global static void doPut(String billingType, String accountName, String subject, String issueType, String opportunityUrl) {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;
    
    // Bail out if bad Jira Issue key
    String issueKey = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
    if (issueKey == null || issueKey == '') {
      res.statusCode = 400;
      return;
    }

    // Get Account.Id for named customer
    Account customer = [SELECT Id FROM Account WHERE Name = :accountName LIMIT 1][0];
    if (customer == null) {
      res.statusCode = 404;
      return;
    }
    ID accountId = customer.Id;

    // Get Opportunity Id
    String billing = billingType;
    ID opportunityId = getSalesforceId(opportunityUrl);
    try {
      billing = [SELECT Billing__c FROM Opportunity WHERE Id = :opportunityId].Billing__c;
    } catch (Exception eOpportunityLookup) {
      System.debug('No opportunity was found.');
    }

    // Find Time Entries for this Jira Issue
    List<Time_Entry__c> timeEntries = [
      SELECT
        Account__c, Resource__c, Activity__c, Role__c, Date_Worked__c,
        Hours__c, Jira_Issue__c, Notes__c, Worklog_ID__c, Hourly_Rate__c,
        Hourly_Cost__c, Billed__c, Billing__c, Entitlement__c, Subject__c,
        Type__c, Opportunity__c
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
          Entitlement__c = timeEntry.Entitlement__c,
          Opportunity__c = timeEntry.Opportunity__c
        );
        // Add it to the list of upserts (upsert in case we do this multiple times)
        reversedTimeEntries.add(reversedTimeEntry);
      }

      // Original gets the updated values
      timeEntry.Billing__c = billing;
      timeEntry.Billed__c = false;
      timeEntry.Subject__c = subject;
      timeEntry.Type__c = issueType;
      timeEntry.Account__c = accountId;
      timeEntry.Opportunity__c = opportunityId;
    }
    
    System.debug(timeEntries);
    update timeEntries;

    System.debug(reversedTimeEntries);
    upsert reversedTimeEntries Worklog_ID__c;

    res.statusCode = 204; // Successfully updated
  }
}