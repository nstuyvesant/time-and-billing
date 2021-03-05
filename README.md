# Zendesk and JIRA with Tempo Timesheets integration with Salesforce and FinancialForce Accounting

## Business Problem
Time worked for several departments needs to be billed monthly to customers using role-based rates established either at the account level or a standard rate card. Some customers have an entitlement of hours granted each year. All time tracked is deducted from that entitlement. After it burns off, the customer is billed hourly according to their rate (or Utilant's rate).

## Tools used

For Engineering, Professional Services, ISS, and Product, time is tracked in **Jira** at the Issue level using the **Tempo Timesheets** product. For Technical Support, time is tracked against **Zendesk** tickets using an optional extension created by Zendesk.

Paid Time Off (PTO) is currently requested and approved in ADP. Neither Jira nor Zendesk has any visibility to banked or approved PTO.

**FinancialForce Accounting** (built on Salesforce) is used for billing, revenue recognition, and amortization of implementation costs across the term of a subscription (ASC 606).

**Salesforce** is used to manage accounts, opportunities, and contacts. Salesforce has been extended to store rates per activity and date range for each account (including the house account), time entries coming from Jira/Tempo and Zendesk, hourly costs for employees (stored as contacts), entitlement and burndown against it using custom fields on account.

## Architectural Approach
Jira, Tempo, Zendesk and ADP provide REST APIs. Salesforce provides a means to make REST Callouts on a scheduled basis from Apex classes. Salesforce has been selected as the platform for synchronization, management, logging, and notification. The intention is for Utilant to internally maintain the synchronization.

Three Salesforce Apex classes will be created:
- TimeAndBilling - methods for synchronizing between Tempo, Jira, Zendesk, ADP, and Salesforce
- TimeAndBillingDaily - Schedulable class meant to run daily imports of time from Jira/Tempo and Zendesk and to push Account and Activity changes to Tempo (might need to be broken down into additional classes due to REST Callout/SOQL queries limitations)
- TimeAndBillingMonthly - Schedulable class to run monthly invoicing

## Required custom fields and objects

### JIRA
- **Billable** - radio button list with values **Yes** and **No**
- **Account** - select list created by Tempo Timesheets and populated from Salesforce Accounts using the Salesforce Id as key

### Tempo Timesheets
- **Activity** - Work attribute select list for worklogs to differentiate work such as Development, Testing, Planning, etc. Rates in Salesforce are based on this

### Zendesk
- **Type** - select list that overrides built-in Zendesk ticket types

### Salesforce

- **Account**
  - **Entitlement Starts** - typically, the Start and End will represent a year of the total subscription
  - **Entitlement Ends** - end of that period
  - **Entitled Hours** - Total hours to burndown
  - **Entitlement Used** - How many hours have been consumed in Time Entries
  - **Entitlement Remaining** - How many hours of the entitlement remaining
  - **Go-Live Date** - End of the customer's implementation period for ASC 606 treatment

- **Contact**
  - **Hourly Cost** - either a tiered cost based on job title or fully-burdened hourly cost (to be restricted to Finance team)

- **Rate** (Rate__c) object
  - **Account** - parent account
  - **Role** - global value set matching Contact.Billing Role
  - **Start Date** - start date for the rate (allows Account Managers to setup price increases)
  - **End Date** - end date for the rate
  - **Hourly Rate** - the rate for that account (note: rack rates are associated with Utilant, LLC)

- **Time Entry** (Time_Entry__c) object
  - **Account** - Lookup(Account)
  - **Resource** - Lookup(Contact), represents the person who tracked time
  - **Activity** - global value set matching select list in Tempo
  - **Role** - global value set matching Contact.Billing Role
  - **Date Worked** - For Jira/Tempo, when work was performed. For Zendesk, the date the ticket was solved.
  - **Hours**
  - **Notes**
  - **Jira Issue** - Jira key
  - **Zendesk Ticket** - Zendesk
  - **Worklog ID** - Tempo's primary key
  - **Billable** - whether the time entry is billable
  - **Billed** - whether time entry has been included in a sales invoice line item
  - **URL** - Direct link to Jira Issue or Zendesk ticket
  - **Hourly Rate** - Rate for the Activity for this Account (customer) or a fallback to rack rate
  - **Hourly Cost** - Cost rate for the resource (Contact).
  - **Revenue** - Hours * Hourly Rate
  - **COGS** - Hours * Hourly Cost
  - **Gross Profit** - Revenue - COGS
  - **Gross Margin** - (Revenue - COGS) / Revenue
  - **Burns Entitlement** - Looked up from Account, used to determine whether time entry falls into entitlement period

- **Time Entries with Accounts** Custom Report Type

- **Named Credentials** - Jira, Tempo, and Zendesk - required for REST Callouts

- **Global Value Set** Activities - matching Tempo Work Attribute select list

## Data setup

- Each resource who tracks time in Jira or Zendesk must have a Contact record associated with Utilant, LLC with a unique Name and Email (lowercase please). That record must also have a Billing Role and Hourly Cost (can be based on title or full-burdened hourly cost for the employee).
- Each customer should have an Account record with Type = "Customer", and Platform and Sales Tax Status fields are not empty.
- Rates for each Role should be associated with Utilant, LLC and customer accounts that have special rates.
- Customers who are on subscription should have a Rate added for Technical Support for $0 as it is not billable.
- All Jira Issues that are billable must have a value for Account and Billable must be Yes.
- Use DateTime.valueOfGmt('2020-11-01 00:00:00') for parameter passed to syncTempoToSalesforce() and syncZendeskToSalesforce()

## Known Limitations
- Salesforce limits the number of queries, data manipulation language (DML), and REST Callouts on a per hour basis. The code is designed to bulkify requests often at the expense of simplicity.
- This integration will not detect Tempo Work Logs deleted that were previously synchronized.
- When deploying code from Salesforce Sandbox to Production, pick "Run specified tests" and paste TimeAndBillingMonthlySpec,TimeAndBillingSpec,TimeAndBillingServiceSpec,TimeAndBillingDailySpec into the text area field then click OK.

## Logic for billing against burndown
- As we iterate through time entries to bill, Account.Remaining Hours will not dynamically update
- We could set a variable for the first time entry for that account, then deduct hours as we go
- currentAccount = null
- For time entries
-   if currentAccount != thisAccount 
- If Account.Entitlement Remaining < 0, burndown is not relevant
- If TODAY < Account.Entitlement Start OR TODAY > Entitlement Ends, burndown is not relevant
- 