@RestResource(urlMapping='/issue/*')
global with sharing class TimeAndBillingService {

  private static final String COMPANY_ACCOUNT_NAME = 'Utilant, LLC';

  
  // Take a Salesforce Lightning URL and return the record Id (return null for bad urls)
  private static ID getSalesforceId(String url) {
    if (url == null) return null;
    Pattern urlPattern = Pattern.compile('.*/lightning/r.*/([a-zA-Z0-9]{15,18})/view');
    Matcher urlMatcher = urlPattern.matcher(url);
    return urlMatcher.matches() ? (ID) urlMatcher.group(1) : null;
  }


  // Create map of roles and rates for query provided
  private static Map<String,Decimal> getRatesMap(String sQuery) {
    List<Rate__c> rates = Database.query(sQuery);
    Map<String,Decimal> ratesMap = new Map<String,Decimal>();
    for (Rate__c rate: rates) {
      ratesMap.put(rate.Role__c, rate.Hourly_Rate__c);
    }
    return ratesMap;
  }


  // Query for customer's rates
  private static Map<String,Decimal> getCustomerRates(ID accountId) {
    return getRatesMap('SELECT Role__c, Hourly_Rate__c FROM Rate__c WHERE Account__c = \'' + String.valueOf(accountId) + '\' AND Start_Date__c <= TODAY AND End_Date__c >= TODAY');
  }


  // Query for rack rates
  private static Map<String,Decimal> getRackRates() {
    return getRatesMap('SELECT Role__c, Hourly_Rate__c FROM Rate__c WHERE Account__r.Name = \'' + COMPANY_ACCOUNT_NAME + '\' AND Start_Date__c <= TODAY AND End_Date__c >= TODAY');
  }


  // Handle PUT from Jira Automation Rule
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
    ID accountId;
    try {
      accountId = [SELECT Id FROM Account WHERE Name = :accountName LIMIT 1].Id;
    } catch (Exception eNoAccount) {
      System.debug('Customer not found.');
      res.statusCode = 404;
      return;
    }

    // Get Opportunity Id
    String billing = billingType;
    ID opportunityId = getSalesforceId(opportunityUrl);
    try {
      billing = [SELECT Billing__c FROM Opportunity WHERE Id = :opportunityId].Billing__c;
    } catch (Exception eOpportunityLookup) {
      System.debug('No opportunity was found.');
    }

    // Populate rate maps
    Map<String,Decimal> customerRatesMap = getCustomerRates(accountId);
    Map<String,Decimal> rackRatesMap = getRackRates();

    // Find Time Entries for this Jira Issue
    List<Time_Entry__c> timeEntries = [
      SELECT
        Account__c, Resource__c, Activity__c, Role__c, Date_Worked__c,
        Hours__c, Jira_Issue__c, Notes__c, Worklog_ID__c, Hourly_Rate__c,
        Hourly_Cost__c, Billing__c, Entitlement__c, Subject__c,
        Type__c, Opportunity__c
      FROM Time_Entry__c
      WHERE Jira_Issue__c = :issueKey And Worklog_ID__c != null AND Billed__c = false
    ];

    // Loop through Time Entries for this Jira Issue
    for (Time_Entry__c timeEntry: timeEntries) {

      // If unbilled time entry is hourly but without a rate, fix it
      if (billing == 'Hourly' && timeEntry.Hourly_Rate__c == 0) {
        Decimal rate = (Decimal) customerRatesMap.get(timeEntry.Role__c);
        Decimal companyRate = (Decimal) rackRatesMap.get(timeEntry.Role__c);
        timeEntry.Hourly_Rate__c = rate != null ? // there is a customer rate
          rate :
          companyRate != null ? // there is a rack rate
          companyRate :
          0; // No rates for this role exist so use $0
      }

      if (billing != 'Hourly') timeEntry.Hourly_Rate__c = 0;

      // Original gets the updated values
      timeEntry.Billing__c = billing;
      timeEntry.Subject__c = subject;
      timeEntry.Type__c = issueType;
      timeEntry.Account__c = accountId;
      timeEntry.Opportunity__c = opportunityId;
    }
    
    update timeEntries;
    System.debug(timeEntries);

    res.statusCode = 204; // Successfully updated
  }
}