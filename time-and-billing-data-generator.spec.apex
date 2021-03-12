@isTest 
public class TimeAndBillingDataGenerator {

  private static final String COMPANY = 'Utilant, LLC';
  private static final Date DAY_LAST_MONTH = Date.today().toStartOfMonth().addDays(-10); // 9 days into last month
  private static final Date INVOICE_DATE = Date.today().toStartOfMonth().addDays(-1); // Last day of prior month
  private static final Date RATE_START = Date.newInstance(System.today().year()-1, 1, 1); // First day of last year
  private static final Date RATE_END = Date.newInstance(System.today().year(), 12, 31); // End of current year

  @isTest
  public static void createTestData() {
    List<Account> accounts = new List<Account>();

    Account company = new Account(  
      Name = COMPANY,
      Type = 'Vendor'
    );
    accounts.add(company);

    Account carrierNotOnSubscription = new Account(
      Name = 'Test Non-Subscription Carrier',
      Type = 'Customer',
      Platform__c = 'Carrier',
      Not_on_subscription__c = true,
      c2g__CODASalesTaxStatus__c = 'Exempt for Qualifying Products'
    );
    accounts.add(carrierNotOnSubscription);

    Account carrierOnSubscription = new Account(
      Name = 'Test Subscription Carrier',
      Type = 'Customer',
      Platform__c = 'Carrier',
      Not_on_subscription__c = false,
      c2g__CODASalesTaxStatus__c = 'Exempt for Qualifying Products'
    );
    accounts.add(carrierOnSubscription);

    Account carrierSubscriptionNullTaxStatus = new Account(
      Name = 'Test Subscription Carrier',
      Type = 'Customer',
      Platform__c = 'Carrier',
      Not_on_subscription__c = false,
      c2g__CODASalesTaxStatus__c = null // intentionally null
    );
    accounts.add(carrierSubscriptionNullTaxStatus);

    Account vendorNotOnSubscription = new Account(  
      Name = 'Test Non-Subscription Vendor',
      Type = 'Customer',
      Platform__c = 'Vendor',
      Not_on_subscription__c = true,
      c2g__CODASalesTaxStatus__c = 'Exempt for Qualifying Products'
    );
    accounts.add(vendorNotOnSubscription);

    Account vendorOnSubscription = new Account(  
      Name = 'Test Subscription Vendor',
      Type = 'Customer',
      Platform__c = 'Vendor',
      Not_on_subscription__c = false,
      c2g__CODASalesTaxStatus__c = 'Exempt for Qualifying Products'
    );
    accounts.add(vendorOnSubscription);

    Account vendorRackRates = new Account(  
      Name = 'Test Non-Subscription Rack Rate Vendor',
      Type = 'Customer',
      Platform__c = 'Vendor',
      Not_on_subscription__c = true,
      c2g__CODASalesTaxStatus__c = 'Exempt for Qualifying Products'
    );
    accounts.add(vendorRackRates);

    insert accounts;

    List<Opportunity> opportunities = new List<Opportunity>();

    Opportunity newSubscriptionOpportunity = new Opportunity(
      Account = carrierOnSubscription,
      Name = 'New: Test Subscription Carrier LC360',
      Type = 'New Logo',
      Billing__c = 'Subscription (Implementation)',
      StageName = 'Closed Won',
      CloseDate = INVOICE_DATE,
      Contract_Start__c = INVOICE_DATE,
      Contract_Length__c = 3
    );
    opportunities.add(newSubscriptionOpportunity);

    Opportunity upgradeOpportunity = new Opportunity(
      Account = vendorNotOnSubscription,
      Name = 'New: Test Non-Subscription Vendor Upgrade',
      Type = 'Change Request',
      Billing__c = 'Hourly',
      StageName = 'Closed Won',
      CloseDate = INVOICE_DATE,
      Contract_Start__c = INVOICE_DATE,
      Contract_Length__c = 3
    );
    opportunities.add(upgradeOpportunity);
    insert opportunities;

    List<Rate__c> rates = new List<Rate__c>();

    // Next two are "rack rates" because they are associated with the company rather than customer

    rates.add(new Rate__c(
      Account__c = company.Id,
      Role__c = 'Executive',
      Hourly_Rate__c = 100,
      Start_Date__c = RATE_START,
      End_Date__c = RATE_END
    ));

    rates.add(new Rate__c(
      Account__c = company.Id,
      Role__c = 'Project Manager',
      Hourly_Rate__c = 95,
      Start_Date__c = RATE_START,
      End_Date__c = RATE_END
    ));

    rates.add(new Rate__c(
      Account__c = company.Id,
      Role__c = 'Technical Support Engineer',
      Hourly_Rate__c = 80,
      Start_Date__c = RATE_START,
      End_Date__c = RATE_END
    ));

    // Customer rates

    rates.add(new Rate__c(
      Account__c = carrierOnSubscription.Id,
      Role__c = 'Executive',
      Hourly_Rate__c = 90,
      Start_Date__c = RATE_START,
      End_Date__c = RATE_END
    ));

    rates.add(new Rate__c(
      Account__c = carrierNotOnSubscription.Id,
      Role__c = 'Technical Support Engineer',
      Hourly_Rate__c = 70,
      Start_Date__c = RATE_START,
      End_Date__c = RATE_END
    ));

    rates.add(new Rate__c(
      Account__c = vendorOnSubscription.Id,
      Role__c = 'Executive',
      Hourly_Rate__c = 91,
      Start_Date__c = RATE_START,
      End_Date__c = RATE_END
    ));

    rates.add(new Rate__c(
      Account__c = vendorNotOnSubscription.Id,
      Role__c = 'Technical Support Engineer',
      Hourly_Rate__c = 73,
      Start_Date__c = RATE_START,
      End_Date__c = RATE_END
    ));

    insert rates;
      
    List<Entitlement__c> entitlements = new List<Entitlement__c>();
      
    Entitlement__c plentyLeft = new Entitlement__c(
     Account__c = carrierOnSubscription.Id,
     Period__c = 'Year',
     Starts__c = RATE_START,
     Ends__c = RATE_END,
     Hours__c = 500,
     Hours_Used__c = 0
    );
    entitlements.add(plentyLeft);

    Entitlement__c oneHourLeft = new Entitlement__c(
     Account__c = carrierNotOnSubscription.Id,
     Period__c = 'Year',
     Starts__c = RATE_START,
     Ends__c = RATE_END,
     Hours__c = 500,
     Hours_Used__c = 499
    );
    entitlements.add(oneHourLeft);
      
    Entitlement__c monthlyEntitlement = new Entitlement__c(
     Account__c = vendorOnSubscription.Id,
     Period__c = 'Month',
     Starts__c = RATE_START,
     Ends__c = RATE_END,
     Hours__c = 3,
     Hours_Used__c = 0
    );
    entitlements.add(monthlyEntitlement);
      
    upsert entitlements;

    List<Contact> contacts = new List<Contact>();

    Contact executive = new Contact(
      LastName = 'Doe',
      FirstName = 'John',
      Email = 'john.doe@test.com',
      AccountId = company.Id,
      Title = 'Executive',
      Financial_Billing_Contact__c = false,
      LeadSource = 'Advertisement',
      Billing_Role__c = 'Executive',
      Hourly_Cost__c = 100.00
    );
    contacts.add(executive);

    Contact projectManager = new Contact(
      LastName = 'Doe',
      FirstName = 'Jane',
      Email = 'jane.doe@test.com',
      AccountId = company.Id,
      Title = 'Project Manager',
      Financial_Billing_Contact__c = false,
      LeadSource = 'Advertisement',
      Billing_Role__c = 'Project Manager',
      Hourly_Cost__c = 100.00
    );
    contacts.add(projectManager);

    Contact resourceNoBillingRole = new Contact(
      LastName = 'Sample',
      FirstName = 'Dennis',
      Email = 'dennis.sample@test.com',
      AccountId = company.Id,
      Title = 'Technical Support Engineer',
      Financial_Billing_Contact__c = false,
      LeadSource = 'Advertisement',
      Billing_Role__c = null,
      Hourly_Cost__c = 57.00
    );
    contacts.add(resourceNoBillingRole);

    Contact supportEngineer = new Contact(
      LastName = 'Example',
      FirstName = 'Trudy',
      Email = 'trudy.example@test.com',
      AccountId = company.Id,
      Title = 'Technical Support Engineer',
      Financial_Billing_Contact__c = false,
      LeadSource = 'Advertisement',
      Billing_Role__c = 'Technical Support Engineer',
      Hourly_Cost__c = 59.00
    );
    contacts.add(supportEngineer);

    insert contacts;

    // Time Entries against Jira Issue

    List<Time_Entry__c> jiraTimeEntries = new List<Time_Entry__c>();

    Time_Entry__c jiraBilled = new Time_Entry__c(
      Account__c = carrierOnSubscription.Id,
      Resource__c = executive.Id,
      Activity__c = 'Discovery',
      Role__c = 'Executive',
      Date_Worked__c = DAY_LAST_MONTH,
      Hours__c = 8,
      Jira_Issue__c = 'PS-001',
      Type__c = 'Story',
      Subject__c = 'Test Story',
      Notes__c = 'Core Sprint Discovery',
      Worklog_ID__c = 1,
      Hourly_Rate__c = 100,
      Billing__c = 'Hourly',
      Billed__c = true,
      Opportunity__c = newSubscriptionOpportunity.Id
    );
    jiraTimeEntries.add(jiraBilled);

    Time_Entry__c jiraUnbilledTSSubcription = new Time_Entry__c(
      Account__c = carrierOnSubscription.Id,
      Resource__c = supportEngineer.Id,
      Activity__c = 'TechnicalSupport',
      Role__c = 'Technical Support Engineer',
      Date_Worked__c = DAY_LAST_MONTH,
      Hours__c = 8,
      Jira_Issue__c = 'PS-001',
      Type__c = 'Story',
      Subject__c = 'Test Story',
      Notes__c = 'Core Sprint Discovery',
      Worklog_ID__c = 2,
      Hourly_Rate__c = 100,
      Billing__c = 'Hourly',
      Billed__c = true
    );
    jiraTimeEntries.add(jiraUnbilledTSSubcription);

    Time_Entry__c jiraUnbilledCoveredByEntitlement = new Time_Entry__c(
      Account__c = carrierOnSubscription.Id,
      Resource__c = executive.Id,
      Activity__c = 'Planning',
      Role__c = 'Executive',
      Date_Worked__c = DAY_LAST_MONTH,
      Hours__c = 1,
      Jira_Issue__c = 'PS-001',
      Type__c = 'Story',
      Subject__c = 'Test Story',
      Notes__c = 'Core Sprint Planning',
      Worklog_ID__c = 3,
      Hourly_Rate__c = 100,
      Billing__c = 'Hourly',
      Billed__c = false
    );
    jiraTimeEntries.add(jiraUnbilledCoveredByEntitlement);

    Time_Entry__c jiraUnbilledRole1 = new Time_Entry__c(
      Account__c = carrierNotOnSubscription.Id,
      Resource__c = executive.Id,
      Activity__c = 'Discovery',
      Role__c = 'Executive',
      Date_Worked__c = DAY_LAST_MONTH,
      Hours__c = 0.5,
      Jira_Issue__c = 'PS-001',
      Type__c = 'Story',
      Subject__c = 'Test Story',
      Notes__c = 'Core Sprint Planning',
      Worklog_ID__c = 4,
      Hourly_Rate__c = 100,
      Billing__c = 'Hourly',
      Billed__c = false,
      Opportunity__c = newSubscriptionOpportunity.Id
    );
    jiraTimeEntries.add(jiraUnbilledRole1);

    Time_Entry__c jiraUnbilledRole2 = new Time_Entry__c(
      Account__c = carrierNotOnSubscription.Id,
      Resource__c = projectManager.Id,
      Activity__c = 'Planning',
      Role__c = 'Project Manager',
      Date_Worked__c = DAY_LAST_MONTH,
      Hours__c = 5,
      Jira_Issue__c = 'PS-001',
      Type__c = 'Story',
      Subject__c = 'Test Story',
      Notes__c = 'Core Sprint Planning',
      Worklog_ID__c = 5,
      Hourly_Rate__c = 100,
      Billing__c = 'Hourly',
      Billed__c = false
    );
    jiraTimeEntries.add(jiraUnbilledRole2);
      
    // Hourly time entry with $0 Hourly Rate
    Time_Entry__c jiraUnbilledRole3 = new Time_Entry__c(
      Account__c = carrierNotOnSubscription.Id,
      Resource__c = executive.Id,
      Activity__c = 'Discovery',
      Role__c = 'Executive',
      Date_Worked__c = DAY_LAST_MONTH,
      Hours__c = 3.5,
      Jira_Issue__c = 'PS-001',
      Type__c = 'Story',
      Subject__c = 'Test Story',
      Notes__c = 'Core Sprint Planning',
      Worklog_ID__c = 6,
      Hourly_Rate__c = 0,
      Billing__c = 'Hourly',
      Billed__c = false,
      Opportunity__c = newSubscriptionOpportunity.Id
    );
    jiraTimeEntries.add(jiraUnbilledRole3);

    Time_Entry__c jiraUnbilledNoEntitlement = new Time_Entry__c(
      Account__c = vendorNotOnSubscription.Id,
      Resource__c = projectManager.Id,
      Activity__c = 'Planning',
      Role__c = 'Project Manager',
      Date_Worked__c = DAY_LAST_MONTH,
      Hours__c = 7,
      Jira_Issue__c = 'VEN-002',
      Type__c = 'Task',
      Subject__c = 'Test Task',
      Notes__c = 'Script to update database',
      Worklog_ID__c = 7,
      Hourly_Rate__c = 100,
      Billing__c = 'Hourly',
      Billed__c = false
    );
    jiraTimeEntries.add(jiraUnbilledNoEntitlement);    
    
    Time_Entry__c jiraBug = new Time_Entry__c(
      Account__c = carrierNotOnSubscription.Id,
      Resource__c = executive.Id,
      Activity__c = 'DefectResolution',
      Role__c = 'Executive',
      Date_Worked__c = DAY_LAST_MONTH,
      Hours__c = 6,
      Jira_Issue__c = 'CAR-123',
      Type__c = 'Bug',
      Subject__c = 'Test Bug',
      Notes__c = 'Test Bug',
      Worklog_ID__c = 8,
      Hourly_Rate__c = 0,
      Billing__c = 'None',
      Billed__c = false
    );
    jiraTimeEntries.add(jiraBug);

    Time_Entry__c jiraUnbilledStoryCustomerNoSalesTax = new Time_Entry__c(
      Account__c = carrierSubscriptionNullTaxStatus.Id,
      Resource__c = projectManager.Id,
      Activity__c = 'Planning',
      Role__c = 'Executive',
      Date_Worked__c = DAY_LAST_MONTH,
      Hours__c = 7,
      Jira_Issue__c = 'CAR-007',
      Type__c = 'Story',
      Subject__c = 'Test Story',
      Notes__c = 'Test Story',
      Worklog_ID__c = 9,
      Hourly_Rate__c = 0,
      Billing__c = 'Hourly',
      Billed__c = false
    );
    jiraTimeEntries.add(jiraUnbilledStoryCustomerNoSalesTax);

    upsert jiraTimeEntries Worklog_ID__c;

    // Zendesk time entries

    List<Time_Entry__c> zendeskTimeEntries = new List<Time_Entry__c>();

    Time_Entry__c zendeskBilled = new Time_Entry__c(
      Account__c = vendorNotOnSubscription.Id,
      Resource__c = supportEngineer.Id,
      Activity__c = 'TechnicalSupport',
      Role__c = 'Technical Support Engineer',
      Date_Worked__c = DAY_LAST_MONTH,
      Hours__c = 6,
      Zendesk_Ticket__c = 4311,
      Type__c = 'Question',
      Subject__c = 'Test Question',
      Notes__c = 'Helped user',
      Hourly_Rate__c = 125,
      Billing__c = 'Hourly',
      Billed__c = true
    );
    zendeskTimeEntries.add(zendeskBilled);

    Time_Entry__c zendeskUnbilledSubscription = new Time_Entry__c(
      Account__c = vendorOnSubscription.Id,
      Resource__c = supportEngineer.Id,
      Activity__c = 'TechnicalSupport',
      Role__c = 'Technical Support Engineer',
      Date_Worked__c = DAY_LAST_MONTH,
      Hours__c = 7,
      Zendesk_Ticket__c = 4312,
      Type__c = 'Question',
      Subject__c = 'Test Question',
      Notes__c = 'Helped user',
      Hourly_Rate__c = 0,
      Billing__c = 'None',
      Billed__c = false
    );
    zendeskTimeEntries.add(zendeskUnbilledSubscription);

    Time_Entry__c zendeskUnbilledNoSubscription = new Time_Entry__c(
      Account__c = vendorNotOnSubscription.Id,
      Resource__c = supportEngineer.Id,
      Activity__c = 'TechnicalSupport',
      Role__c = 'Technical Support Engineer',
      Date_Worked__c = DAY_LAST_MONTH,
      Hours__c = 8,
      Zendesk_Ticket__c = 4313,
      Type__c = 'Problem',
      Subject__c = 'Test Problem',
      Notes__c = 'Helped user',
      Hourly_Rate__c = 124,
      Billing__c = 'Hourly',
      Billed__c = false
    );
    zendeskTimeEntries.add(zendeskUnbilledNoSubscription);

    Time_Entry__c zendeskUnbilledNoSubscriptionBug = new Time_Entry__c(
      Account__c = vendorNotOnSubscription.Id,
      Resource__c = supportEngineer.Id,
      Activity__c = 'DefectResolution',
      Role__c = 'Technical Support Engineer',
      Date_Worked__c = DAY_LAST_MONTH,
      Hours__c = 9,
      Zendesk_Ticket__c = 4314,
      Type__c = 'Defect',
      Subject__c = 'Test Defect',
      Notes__c = 'Helped user',
      Hourly_Rate__c = 0,
      Billing__c = 'None',
      Billed__c = false
    );
    zendeskTimeEntries.add(zendeskUnbilledNoSubscriptionBug);

    upsert zendeskTimeEntries Zendesk_Ticket__c;
  }
}