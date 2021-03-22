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


  // Handle PUT from Jira Automation Rule for changes to key Jira Issue fields
  @HttpPut
  global static void doPut(String billingType, String accountName, String subject, String issueType, String opportunityUrl) {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;
    
    // Bail out if bad Jira Issue key
    String issueKey = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
    if (issueKey == null || issueKey == '') {
      System.debug('Issue Key not specified.');
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

    // Get Opportunity Id to link to Time Entry
    String billing = billingType;
    ID opportunityId = getSalesforceId(opportunityUrl);
    try {
      billing = [SELECT Billing__c FROM Opportunity WHERE Id = :opportunityId].Billing__c;
      if (billing == null) billing = billingType;
    } catch (Exception eOpportunityLookup) {
      System.debug('No opportunity was found.');
    }

    // Populate rate maps
    Map<String,Decimal> customerRatesMap = getCustomerRates(accountId);
    Map<String,Decimal> rackRatesMap = getRackRates();

    // Find Time Entries for this Jira Issue
    List<Time_Entry__c> timeEntries = [
      SELECT
        Account__c, Billed__c, Hourly_Rate__c, Billing__c, Role__c,
        Opportunity__c, Type__c, Subject__c
      FROM Time_Entry__c
      WHERE Jira_Issue__c = :issueKey AND Worklog_ID__c != null
    ];

    // Loop through Time Entries for this Jira Issue
    for (Time_Entry__c timeEntry: timeEntries) {

      // If time entry billed, only update Subject, Type, Opportunity
      if (!timeEntry.Billed__c) {

        // If hourly without rate, fix
        if (billing == 'Hourly' && timeEntry.Hourly_Rate__c == 0) {
          Decimal rate = (Decimal) customerRatesMap.get(timeEntry.Role__c);
          Decimal companyRate = (Decimal) rackRatesMap.get(timeEntry.Role__c);
          timeEntry.Hourly_Rate__c = rate != null ? // there is a customer rate
            rate :
            companyRate != null ? // there is a rack rate
            companyRate :
            0; // No rates for this role exist so use $0
        }

        // All non-hourly time entries should have $0 rate
        if (billing != 'Hourly') timeEntry.Hourly_Rate__c = 0;

        timeEntry.Account__c = accountId;
        timeEntry.Billing__c = billing;
      } // not billed

      // Updated whether billed or not
      timeEntry.Subject__c = subject;
      timeEntry.Type__c = issueType;
      timeEntry.Opportunity__c = opportunityId;
    }
    
    update timeEntries;
    System.debug(timeEntries);

    res.statusCode = 204; // Successfully updated
  }
}