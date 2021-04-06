public class TimeAndBilling {
  private virtual class TimeAndBillingException extends Exception {}
  private class JiraException extends TimeAndBillingException {}
  private class TempoException extends TimeAndBillingException {}
  private class ZendeskException extends TimeAndBillingException {}

  // Jira

  private class JiraQuery {
    private String jql;
    private Integer maxResults;
    private String[] fields;
    private Integer startAt;
  }

  private class JiraField {
    private String value;
  }

  private class JiraIssueType {
    private String name;
  }

  private class JiraFields {
    private string summary;
    private JiraIssueType issuetype;
    private JiraField customfield_10090; // Billing
    private String customfield_10113; // Salesforce Opportunity
    private JiraField customfield_10086; // Salesforce Account
  }

  private class JiraIssue {
    private Integer id;
    private String key;
    private JiraFields fields;
  }

  private class JiraSearchResults {
    private Integer startAt;
    private Integer maxResults;
    private Integer total;
    private JiraIssue[] issues;
  }

  private class JiraUser {
    private String accountId;
    private String displayName;
    private String emailAddress;
    private Boolean active;
  }

  // Tempo

  private class TempoMetaData {
    private Long count;
    private Long offset;
    private Long limitReserved; // actually "limit" but it's reserved
    private String next;
  }

  private class TempoIssue {
    private String key;
    private Long id;
  }

  private class TempoAuthor {
    private String accountId;
    private String displayName;
  }

  private class TempoWorkAttributeValue {
    private String key;
    private String value;
  }

  private class TempoAttributes {
    private TempoWorkAttributeValue[] values;
  }

  private class TempoWorklog {
    private Long tempoWorklogId;
    private TempoIssue issue;
    private Decimal timeSpentSeconds;
    private Date startDate;
    private String description;
    private DateTime createdAt;
    private DateTime updatedAt;
    private TempoAuthor author;
    private TempoAttributes attributes;
  }

  private class TempoWorklogDeleted {
    private DateTime deletedAt;
    private String tempoWorklogId;
  }

  private virtual class TempoDownload {
    private TempoMetaData metadata;
  }

  private class TempoWorkLogs extends TempoDownload {
    private TempoWorklog[] results;
  }

  private class TempoWorkLogsDeleted extends TempoDownload {
    private TempoWorklogDeleted[] results;
  }

  private class TempoType {
    private String type;
  }

  private class TempoRecurrence {
    private String rule;
    private Date recurrenceEndDate;
  }

  private class TempoDateValue {
    private Date fromReserved;
    private Date to;
    private Integer timePlannedSeconds;
  }

  private class TempoDates extends TempoDownload {
    private TempoDateValue[] results;
  }

  private class TempoAccount {
    private String key; // Salesforce Account.Id
    private String name; // Account.Name
    private String status; // 'OPEN'
    private String leadAccountId; // use '5eb577fb0590bb0b7b3986e8' (Scott)
    private Boolean globalReserved; // optional - defaults to false
  }

  private class TempoAccounts extends TempoDownload {
    private TempoAccount[] results;
  }

  private class TempoActivities {
    private String key; // "_Activities_"
    private Boolean required; // false
    private String[] values;
  }

  // Zendesk

  private class ZendeskCustomField {
    private Long id;
    private String value; // can be null
  }

  private class ZendeskTicket {
    private Long id;
    private String type;
    private String subject;
    private String status;
    private Long assignee_id;
    private Long organization_id;
    private DateTime updated_at;
    private ZendeskCustomField[] custom_fields;
  }

  private virtual class ZendeskSearchResults {
    private Integer count;
    private String next_page; // null if done
  }

  private class ZendeskTicketsFound extends ZendeskSearchResults {
    private ZendeskTicket[] results;
  }

  private class ZendeskOrganization {
    private Long id;
    private String name;
  }

  private class ZendeskOrganizationsFound extends ZendeskSearchResults {
    private ZendeskOrganization[] results;
  }

  private class ZendeskAgent {
    private Long id;
    private String name;
    private String email;
  }

  private class ZendeskAgentsFound extends ZendeskSearchResults {
    private ZendeskAgent[] users;
  }

  // Constants
  private static final String COMPANY_ACCOUNT_NAME = 'Utilant, LLC';
  private static final String CURRENCY_NAME = 'USD';
  private static final String JIRA_DEFAULT_OWNER_ID = '5eb577fb0590bb0b7b3986e8'; // Scott
  private static final String JIRA_ENDPOINT = 'callout:Jira/rest/api/3';
  private static final Integer MAX_TEXT_LENGTH = 131072;
  private static final Decimal RESOURCE_DEFAULT_HOURLY_COST = 49.0;
  private static final String SERVICE_PRODUCT = 'Service: Professional Services (Hour)';
  private static final ID SUPPORT_NO_CUSTOMER = '0011U00000rZRzpQAG'; // RapidSketch Sales
  private static final String TEMPO_CALLOUT = 'callout:Tempo';
  private static final String TEMPO_CORE_API = '/core/3';
  private static final String TEMPO_AUDIT_API = '/audit/1';
  private static final Date WORKLOGS_CUTOFF = Date.newInstance(2020, 1, 1);
  private static final String ZENDESK_BASE_URI = 'https://utilant.zendesk.com/api/v2';
  private static final String ZENDESK_ENDPOINT = 'callout:Zendesk/api/v2';
  private static final Integer ZENDESK_MAX_RECORDS = 100;
  private static final String[] ZENDESK_NONBILLABLE_TYPES = new String[]{'Defect', 'Incident', 'Service degradation', 'Outage'}; // latter 2 are deprecated
  private static final Long ZENDESK_SECONDS_FIELD = 360030708654L;
  private static final Long ZENDESK_TYPE_FIELD = 360030745593L;
  private static final Integer DML_ROW_BUFFER = 50; // prevent DML 10K limit from being hit


  // Get Map of SObject from List<SObject> using one or more fields separated by semicolons
  private static Map<String, SObject> getSObjectMap(List<SObject> records, String fields) {
    // Workaround to strongly type SObject for recasting
    String sObjectTypeString = String.valueOf(records.getSObjectType());
    Type t = Type.forName('Map<String,' + sObjectTypeString + '>');
    Map<String, SObject> mapRecords = (Map<String, SObject>) t.newInstance();

    List<String> fieldNames = fields.split(';'); // multiple field key separator

    // Create key from the value of each field in fieldNames
    for (SObject record: records) {
      String key = '';
      for (String fieldName: fieldNames) {
        key += String.valueOf(record.get(fieldName));
      }
      mapRecords.put(key, record);
    }

    return mapRecords;
  }


  // Add a Time Billing Audit record to log summaries of activity
  private static Time_Billing_Audit__c createLogEntry(String operation, String status, String summary, String previousValue, String newValue) {
    String trimmedPrevious = previousValue != null && previousValue.length() > MAX_TEXT_LENGTH ? previousValue.left(MAX_TEXT_LENGTH) : previousValue;
    String trimmedNew = newValue != null && newValue.length() > MAX_TEXT_LENGTH ? newValue.left(MAX_TEXT_LENGTH) : newValue;
    return new Time_Billing_Audit__c(
      Timestamp__c = System.now(),
      Operation__c = operation,
      Status__c = status,
      Summary__c = summary,
      Previous_Value__c = trimmedPrevious,
      New_Value__c = trimmedNew
    );
  }


  // Take a Salesforce Lightning URL and return the record Id (return null for bad urls)
  public static ID getSalesforceId(String url) {
    if (url == null) return null;
    Pattern urlPattern = Pattern.compile('.*/lightning/r.*/([a-zA-Z0-9]{15,18})/view');
    Matcher urlMatcher = urlPattern.matcher(url);
    return urlMatcher.matches() ? (ID) urlMatcher.group(1) : null;
  }


  // Set headers, method, and URI for REST Callouts
  private static HttpRequest setupHttpRequest(string method, string endPoint) {
    HttpRequest request = new HttpRequest();
    request.setMethod(method);
    request.setHeader('Content-Type', 'application/json');
    request.setHeader('Accept', 'application/json');
    request.setEndpoint(endPoint);
    return request;
  }


  // Any interactions with Tempo APIs (core and audit)
  private static HttpResponse tempoApi(String method, String api, String endpoint, String jsonBody) {
    String uri = TEMPO_CALLOUT + api + endpoint;
    HttpRequest request = setupHttpRequest(method, uri);
    request.setTimeout(30000);

    // Workaround for non-standard credential passing
    request.setHeader('Authorization', 'Bearer {!$Credential.Password}');

    if (jsonBody != null) {
      request.setBody(jsonBody);
    }

    HttpResponse response;
    try {
      response = new Http().send(request);
    } catch (Exception eTempoSendRequest) {
      throw new TempoException('Exception thrown: ' + eTempoSendRequest.getMessage()); 
    }
    return response;
  }


  // Get Accounts in Tempo
  private static TempoAccount[] getAccountsFromTempo(List<Time_Billing_Audit__c> logEntries) {
    // Get the list of Accounts (customers) from Tempo (their key is a Production Salesforce Id)
    HttpResponse response = tempoApi('GET', TEMPO_CORE_API, '/accounts', null);

    // Log issue and throw error
    if (response.getStatusCode() != 200) {
      Time_Billing_Audit__c logEntry = createLogEntry('Tempo: Get Accounts', 'Failure',
        'Could not connect to Tempo to get Accounts list. Status Code: ' + String.valueOf(response.getStatusCode()),
        null, null);
      logEntries.add(logEntry);
      throw new TempoException(logEntry.Summary__c);
    }

    // Deserialize Tempo Accounts 
    String jsonBody = response.getBody();
    TempoAccounts deserializedResponse = (TempoAccounts) JSON.deserialize(jsonBody, TempoAccounts.class);

    return deserializedResponse.results; // only care about the array of results
  }


  // Get list of deleted worklogs from Temp (known issue: if > 1000 deletions, only first 1000 will be removed)
  private static TempoWorklogDeleted[] getTempoDeletedWorklogs(DateTime deletedSince) {
    String isoDateTime = deletedSince.format('yyyy-MM-dd', 'GMT') + 'T00:00:00.000Z';
    try {
      HttpResponse response = tempoApi('GET', TEMPO_AUDIT_API, '/events/deleted/types/worklog?limit=1000&updatedFrom=' + isoDateTime, null);
      if (response.getStatusCode() != 200) {
        throw new TempoException('Could not get deleted worklogs from Tempo');
      }
      String jsonBody = response.getBody();
      TempoWorkLogsDeleted deserializedResponse = (TempoWorkLogsDeleted) JSON.deserialize(jsonBody, TempoWorkLogsDeleted.class);
      return deserializedResponse.results;
    } catch (Exception eTempoWorklogsDeleted) {
      System.debug(eTempoWorklogsDeleted);
      return null;
    }
  }


  // Delete worklogs in Salesforce
  @future(callout=true)
  public static void syncTimeEntryDeletions(DateTime deletedSince) {
    TempoWorklogDeleted[] deletedWorklogs = getTempoDeletedWorklogs(deletedSince);
    Set<Long> worklogIds = new Set<Long>();
    for (TempoWorkLogDeleted deletedWorklog: deletedWorklogs) {
      worklogIds.add(Long.valueOf(deletedWorklog.tempoWorklogId));
    }
    List<Time_Entry__c> timeEntriesToDelete = [SELECT Id FROM Time_Entry__c WHERE Worklog_ID__c IN :worklogIds];
    delete timeEntriesToDelete;
    System.debug('Deleted ' + String.valueOf(timeEntriesToDelete.size()) + ' time entries from Salesforce to match deletions in Tempo.');
  }


  // Send a Salesforce Account (Type = Customer, Platform is not empty) to Tempo to populate Select List
  private static void syncAccountToTempo(String method, Account account, String jiraAccountId) {
    TempoAccount tempoAccount = new TempoAccount();
    tempoAccount.name = account.Name;
    tempoAccount.key = String.valueOf(account.Id);
    tempoAccount.status = 'OPEN';
    tempoAccount.leadAccountId = jiraAccountId;
    tempoAccount.globalReserved = true;
    String jsonBody = JSON.serialize(tempoAccount);
    jsonBody = jsonBody.replace('"globalReserved"', '"global"'); // rename global property as it is a reserved word in Apex
    HttpResponse response = tempoApi(method, TEMPO_CORE_API, '/accounts', jsonBody);
    Integer responseCode = response.getStatusCode();
    if (responseCode != 200 && responseCode != 204) { // logging occurs in calling method
      throw new TempoException('Error: could not connect to Tempo to send an account. Status Code: ' + String.valueOf(response.getStatusCode()));
    }
  }


  // Generate map (key = Salesforce Id, value = Account.Name) from Tempo
  private static Map<ID,String> getAccountNameFromTempoAccountId(List<Time_Billing_Audit__c> logEntries) {
    Map<ID,String> tempoAccountsMap = new Map<ID,String>();

    // Get all Accounts from Tempo
    TempoAccount[] tempoAccounts = getAccountsFromTempo(logEntries);

    // Create Map of Accounts in Tempo (only ID and Name)
    tempoAccountsMap = new Map<ID,String>();
    for (TempoAccount tempoAccount: tempoAccounts) {
      ID accountId = (ID) tempoAccount.key; // cast as Salesforce Id
      tempoAccountsMap.put(accountId, tempoAccount.name);
    }

    return tempoAccountsMap;
  }


  // Generates request for next page of data from Tempo
  private static String getNextUri(Integer offset, DateTime syncDate) {
    return '/worklogs?limit=1000&offset=' + String.valueOf(offset) + '&updatedFrom=' + syncDate.format('yyyy-MM-dd', 'GMT');
  }


  // Called by syncTempoToSalesforce() to get worklogs and create Time Entry records daily, pass logEntries by ref
  private static List<TempoWorklog> getWorklogsFromTempo(DateTime syncDate, List<Time_Billing_Audit__c> logEntries) {
    List<TempoWorklog> tempoWorklogs = new List<TempoWorklog>();
    Integer offset = 0; // Salesforce DML limit is 10,000 records

    try {
      TempoWorklogs deserializedResponse;
      do {
        String nextUri = getNextUri(offset, syncDate);
        HttpResponse response = tempoApi('GET', TEMPO_CORE_API, nextUri, null);

        // Make sure we got results
        if (response.getStatusCode() != 200) {
          Time_Billing_Audit__c logEntry = createLogEntry('Tempo: Get Worklogs', 'Failure',
            'Could not connect to Tempo to retrieve worklogs. Status Code: ' + String.valueOf(response.getStatusCode()),
            null, null);
          logEntries.add(logEntry);
          throw new TempoException(logEntry.Summary__c);
        }

        // Deserialize Tempo Accounts and add to list
        String jsonBody = response.getBody();
        jsonBody.replace('"limit":', '"limitReserved":'); // rename limit property as it is a reserved word in Apex
        deserializedResponse = (TempoWorklogs) JSON.deserialize(jsonBody, TempoWorklogs.class);
        tempoWorklogs.addAll(deserializedResponse.results);

        offset += 1000;
      } while (deserializedResponse.metadata.next != null && offset < 10000);
    } catch (Exception eTempoWorklogs) {
      System.debug('Fail: Getting worklogs from Tempo - ' + eTempoWorklogs.getMessage());
    }

    return tempoWorklogs;
  }


  // Put Tempo Work Attributes in a map
  private static Map<String,String> getAttributesMap(TempoWorkAttributeValue[] attributes) {
    Map<String,String> attributesMap = new Map<String,String>();
    for (TempoWorkAttributeValue attribute: attributes) {
      attributesMap.put(attribute.key, attribute.value);
    }
    return attributesMap;
  }


  // Any interactions with Jira API
  private static HttpResponse jiraApi(String method, String endpoint, String jsonBody) {
    String uri = JIRA_ENDPOINT + endPoint;
    HttpRequest request = setupHttpRequest(method, uri);

    if (jsonBody != null) {
      request.setBody(jsonBody);
    }

    HttpResponse response = new Http().send(request);
    return response;
  }


  // Get Users Map (key = Jira accountId, value = JiraUser)
  private static Map<String,JiraUser> getUsersMapFromJira(String propertyName, List<Time_Billing_Audit__c> logEntries) {
    Map<String,JiraUser> thisMap = new Map<String,JiraUser>();
    
    // BUG: Will not support > 999 Jira Users (we're a long way off of that but limitations should not be built-in)
    // TODO: As this is not a well-paginated API, add do loop and keep requesting until we get an error.
    HttpResponse response = jiraApi('GET', '/users/search?maxResults=1000', null);

    // Make sure we got results
    if (response.getStatusCode() != 200) {
      Time_Billing_Audit__c logEntry = createLogEntry('Jira: Get Users', 'Failure',
        'Could not connect to Jira to retrieve user list. Status Code: ' + String.valueOf(response.getStatusCode()),
        null, null);
      logEntries.add(logEntry);
      throw new JiraException(logEntry.Summary__c);
    }

    // Deserialize Jira users
    String jsonBody = response.getBody();
    List<JiraUser> users = (List<JiraUser>) JSON.deserialize(jsonBody, List<JiraUser>.class);

    // Add user's Id and object to the map
    for (JiraUser user: users) {
      // Due to Apex not being able to refer to properties by a string, hacky approach to prevent repeating this method
      String key = propertyName == 'accountId' ? user.accountId : user.emailAddress;
      thisMap.put(key, user);
    }

    return thisMap;
  }


  // Create Map (key = issue, value = JiraFields)
  private static Map<String,JiraFields> getIssueFieldsFromJira(Datetime syncDate, List<Time_Billing_Audit__c> logEntries) {
    Map<String,JiraFields> issueFieldsMap = new Map<String,JiraFields>(); // return value
    String endPoint = '/search';

    // Search for issues with worklogs updated since syncDate
    JiraQuery jiraQuery = new JiraQuery();
    // Filtering on worklogDate >= 2021-01-01 means "only show issues with a worklog" (dropped ,'GMT' from syncDate.format)
    jiraQuery.jql = 'worklogDate >= 2021-01-01 AND project in (AM,CAR,CP,DS,IMTI,ISD,PS,VEN,UT) AND updatedDate>=' + syncDate.format('yyyy-MM-dd');
    // BUG/FLAW: Jira IGNORES maxResults = 1000 unless the fields are id or key - otherwise 100
    jiraQuery.maxResults = 1000;
    jiraQuery.fields = new String[]{'issuetype', 'summary', 'customfield_10090', 'customfield_10113', 'customfield_10086'};
    jiraQuery.startAt = 0;

    try {
      JiraSearchResults results;

      // Keep requesting until we reach end
      do {
        String jsonRequest = JSON.serialize(jiraQuery);
        HttpResponse response = jiraApi('POST', endPoint, jsonRequest);

        // Make sure we got results
        if (response.getStatusCode() != 200) {
          throw new JiraException('Could not connect to Jira to retrieve recently modified issues. Status Code: ' + String.valueOf(response.getStatusCode()));
        }

        // Deserialize Jira Issues Found
        String jsonResponse = response.getBody();
        results = (JiraSearchResults) JSON.deserialize(jsonResponse, JiraSearchResults.class);

        // Add Jira Issue key to Map
        for (JiraIssue issue: results.issues) {
          issueFieldsMap.put(issue.key, issue.fields);
          jiraQuery.startAt++;
        }
      } while (jiraQuery.startAt < results.total);
    } catch (Exception eJiraBillableIssues) {
      Time_Billing_Audit__c logEntry = createLogEntry('Jira: Get fields from Issues with recent worklogs', 'Failure',
        eJiraBillableIssues.getMessage(), null, JSON.serializePretty(jiraQuery));
      logEntries.add(logEntry);
      throw new JiraException(eJiraBillableIssues.getMessage()); // bubble up after logging
    }

    return issueFieldsMap;
  }


  // List of customers (and prospects) from Salesforce
  private static List<Account> getCustomersFromSalesforce() {
    return [
      SELECT Id, Name, Platform__c, Owner.Name, Owner.Email, Not_on_subscription__c
      FROM Account
      WHERE (Type IN ('Customer','Prospect') AND
        Platform__c != null) OR Name = :COMPANY_ACCOUNT_NAME
      ORDER BY Platform__c, Name
    ];
  }


  // Returns ratesMap (key = Account and Role, value = hourly rate) - static, must populate parameter passed by reference as statics can't handle SObject types
  private static Map<String,SObject> getRatesFromSalesforce() {
    List<Rate__c> rates = [
      SELECT Account__c, Role__c, Hourly_Rate__c
      FROM Rate__c
      WHERE Start_Date__c <= TODAY AND End_Date__c >= TODAY
    ];
    return (Map<String,Rate__c>) getSObjectMap(rates, 'Account__c;Role__c');
  }


  // Get company Id from Salesforce instance
  private static ID getCompanyId() {
    List<Account> accounts = [SELECT Id FROM Account WHERE Name = :COMPANY_ACCOUNT_NAME];
    if (accounts.IsEmpty()) {
      return null; 
    } else return accounts[0].Id;
  }


  // Create Map (key = email, value = Contact) of Resources (Contacts for Utilant, LLC) for lookups
  private static Map<String,Contact> getResourcesMapFromSalesforce(Set<String> resourcesEmailSet) {
    List<Contact> resources = [
      SELECT Id, Email, Name, Billing_Role__c, Hourly_Cost__c, Account.Name
      FROM Contact
      WHERE Account.Name = :COMPANY_ACCOUNT_NAME AND Email IN :resourcesEmailSet
    ];
    Map<String,Contact> resourcesMap = new Map<String,Contact>();
    for (Contact resource: resources) {
      resourcesMap.put(resource.Email, resource);
    } // for

    return resourcesMap;
  }


  // Reverse billed time entries
  private static void reverseBilledTimeEntries(Map<Long,TempoWorklog> worklogsMap, List<Time_Billing_Audit__c> logEntries) {
    // Time Entries matching uploaded worklog Ids that were invoiced
    List<Time_Entry__c> billedTimeEntries = [
      SELECT Account__c, Resource__c, Activity__c, Role__c, Date_Worked__c, Hours__c, Jira_Issue__c, Zendesk_Ticket__c,
        Notes__c, Worklog_ID__c, Hourly_Rate__c, Hourly_Cost__c, Billing__c, Entitlement__c, Type__c, Subject__c
      FROM Time_Entry__c
      WHERE Billed__c = true AND Worklog_ID__c IN :worklogsMap.keySet()
    ];

    // Reverse each billed time entry
    List<Time_Entry__c> reversedTimeEntries = new List<Time_Entry__c>();
    for (Time_Entry__c billedTimeEntry: billedTimeEntries) {
      // Get the worklog matching billedTimeEntry
      TempoWorklog worklog = (TempoWorklog) worklogsMap.get((Long) billedTimeEntry.Worklog_ID__c);
      Decimal hours = worklog.timeSpentSeconds / 3600;

      // if hours did not change, ignore (changes in Tempo to date worked will create new Worklog ID)
      if (hours == billedTimeEntry.Hours__c) {
        continue;
      }

      System.debug('Original hours: ' + String.valueOf(billedTimeEntry.Hours__c) + ', New hours: ' + String.valueOf(hours));

      Time_Entry__c reversedTimeEntry = new Time_Entry__c(
        Account__c = billedTimeEntry.Account__c,
        Resource__c = billedTimeEntry.Resource__c,
        Activity__c = billedTimeEntry.Activity__c,
        Role__c = billedTimeEntry.Role__c,
        Date_Worked__c = billedTimeEntry.Date_Worked__c,
        Hours__c = - billedTimeEntry.Hours__c, // negative hours
        Hourly_Rate__c = billedTimeEntry.Hourly_Rate__c,
        Hourly_Cost__c = billedTimeEntry.Hourly_Cost__c,
        Billed__c = false,
        Billing__c = billedTimeEntry.Billing__c,
        Jira_Issue__c = billedTimeEntry.Jira_Issue__c,
        Notes__c = billedTimeEntry.Notes__c + ' Original Worklog ID: ' + billedTimeEntry.Worklog_ID__c,
        Entitlement__c = billedTimeEntry.Entitlement__c,
        Type__c = billedTimeEntry.Type__c,
        Subject__c = billedTimeEntry.Subject__c
      );
      reversedTimeEntries.add(reversedTimeEntry);
    } // for

    upsert reversedTimeEntries;

    // Log original time entries that were reversed along with new values
    if (reversedTimeEntries.size() > 0) {
      String msg = 'Reversed ' + String.valueOf(reversedTimeEntries.size()) + ' previously billed Time Entry records.';
      Time_Billing_Audit__c logEntry = createLogEntry('Salesforce: Reverse Time Entries', 'Success', msg, 
        JSON.serializePretty(billedTimeEntries), JSON.serializePretty(reversedTimeEntries));
      logEntries.add(logEntry);
      System.debug(msg);
    }
  } // method revereBilledTimeEntries()


  // Convert Tempo Worklogs into Salesforce Time Entries, logEntries by ref
  private static List<Time_Entry__c> workLogsToTimeEntries(DateTime syncDate, TempoWorklog[] worklogs, List<Time_Billing_Audit__c> logEntries) {
    // Get Map (key = Jira accountId, value = JiraUser)
    Map<String,JiraUser> usersMap = getUsersMapFromJira('accountId', logEntries);

    // Generate Map of recently updated Issues (key) with Billable field as value
    Map<String,JiraFields> issueFieldsMap = getIssueFieldsFromJira(syncDate, logEntries);

    // Create map of Tempo accounts and Salesforce Accounts in case Account Id from Tempo is for Production while running in Sandbox 
    Map<ID,String> tempoAccountsMap = getAccountNameFromTempoAccountId(logEntries);
    Map<String,Account> salesforceCustomersMap = getAccountsMapFromSalesforce();

    // Create Map and Set of unique worklog IDs and resource emails to narrow subsequent queries
    Map<Long,TempoWorklog> worklogsMap = new Map<Long,TempoWorklog>();
    Set<String> resourcesEmailSet = new Set<String>();
    for (TempoWorklog worklog: worklogs) {
      worklogsMap.put(worklog.tempoWorklogId, worklog);
      JiraUser user = (JiraUser) usersMap.get(worklog.author.accountId);
      if (user == null) {
        Time_Billing_Audit__c logEntry = createLogEntry('Jira/Tempo User Import', 'Warning',
          'User for this worklog is null. Please make sure the Tempo API user is a member of a group granted the Permission View All Worklogs in the Permission Scheme for the Project containing issue ' + worklog.issue.key,
          JSON.serializePretty(worklog), null);
        logEntries.add(logEntry);
        System.debug('User with ' + worklog.author.accountId + ' not in map from Jira. Worklog = ' + worklog);
        continue;
      }
      resourcesEmailSet.add(user.emailAddress);
    }

    // Create Map (key = email, value = Contact) of Resources (Contacts for Utilant, LLC) for lookups
    Map<String,Contact> resourcesMap = getResourcesMapFromSalesforce(resourcesEmailSet);

    // Customer and rack rate card lookup
    Map<String, Rate__c> ratesMap = (Map<String, Rate__c>) getRatesFromSalesforce();
    ID companyId = getCompanyId(); // Get Utilant ID for rack rate lookup

    // Reverse billed time entries
    reverseBilledTimeEntries(worklogsMap, logEntries);

    // Setup logging
    Time_Billing_Audit__c logEntry;

    // Upsert worklogs to Time Entries (overriding ones we reversed)
    List<Time_Entry__c> timeEntries = new List<Time_Entry__c>();
    for (TempoWorklog worklog: worklogs) {
      // Get attributes associated with this worklog (activity and customer's Account.Id)
      Map<String,String> attributesMap = getAttributesMap(worklog.attributes.values);

      // TODO: Once Tempo fixes their API to not strip out spaces, update the API names of the Activity Picklist Value Set in Salesforce
      String activity = (String) attributesMap.get('_Activity_');
      activity = activity == null ? 'Task' : activity; // Default to task if not set

      if (worklog.author.accountId == '557058:f58131cb-b67d-43c7-b30d-6b58d40bd077') continue; // Automation for Jira User

      // Get resource (Contact) by translating worklog's accountId
      JiraUser jiraUser = (JiraUser) usersMap.get(worklog.author.accountId);
      Contact resource = (Contact) resourcesMap.get(jiraUser.emailAddress);
      if (resource == null) {
        System.debug('Jira User ' + worklog.author.displayName + ' needs a matching Utilant Contact email. Please fix and resync.');
        continue;
      }

      // Flag missing hourly costs for resources
      if (resource.Hourly_Cost__c == null) {
        logEntry = createLogEntry('Salesforce: Resource Cost Lookup', 'Warning',
          resource.Name + ' does not have an Hourly Cost entered. Please make sure all resources have an Hourly Cost. Using default cost.',
          JSON.serializePretty(resource), null);
        resource.Hourly_Cost__c = RESOURCE_DEFAULT_HOURLY_COST;
        logEntries.add(logEntry);
        System.debug(logEntry);
      }

      // Retrieve Jira fields (Account, Billing, and Salesforce Opportunity)
      JiraFields issueFields = (JiraFields) issueFieldsMap.get(worklog.issue.key);

      // No fields because Jira Issue not found? Skip time entry and log.
      if (issueFields == null) {
        String msg = worklog.issue.key + ' not found in issueFieldsMap for ' + String.valueOf(worklog.startDate) + '. In most cases, this means the Jira Issue was not modified as of the worklog startDate or the Jira Issue was deleted.';
        logEntry = createLogEntry('Jira: Issue lookup', 'Failure', msg,
          JSON.serializePretty(worklog), null);
        logEntries.add(logEntry);
        System.debug(msg);
        System.debug(JSON.serializePretty(worklog));
        continue;
      }

      // Lookup customer using Jira custom field 10086
      String customerName = issueFields.customfield_10086 != null && issueFields.customfield_10086.value != null ? issueFields.customfield_10086.value : COMPANY_ACCOUNT_NAME;
      Account customer = (Account) salesforceCustomersMap.get(customerName);
      if (customer == null) {
        String msg = customerName + ' not found in Salesforce. Make sure this account exists in the Salesforce environment; Production accounts are synchronized with Tempo while Sandbox accounts are not.';
        logEntry = createLogEntry('Salesforce: Customer lookup', 'Failure', msg,
          JSON.serializePretty(worklog), null);
        logEntries.add(logEntry);
        System.debug(msg);
        continue;
      }

      ID customerId = customer.Id;
      Boolean onSubscription = !customer.Not_on_subscription__c;
      String billingType = issueFields.customfield_10090 != null && issueFields.customfield_10090.value != null ? issueFields.customfield_10090.value : 'None';
      Boolean isBillable = activity != 'DefectResolution' && billingType == 'Hourly'; // defects should never be billable, but accidents can happen

      // Determine hourly rate for role (check customer, then company/rack rates, then zero)
      Decimal hourlyRate = 0;
      if (isBillable && customerName != COMPANY_ACCOUNT_NAME) {
        Rate__c rateCard = (Rate__c) ratesMap.get(String.valueOf(customerId) + resource.Billing_Role__c);
        Rate__c companyRateCard = (Rate__c) ratesMap.get(String.valueOf(companyId) + resource.Billing_Role__c);
        hourlyRate = rateCard != null ?
          rateCard.Hourly_Rate__c : // if rate card for customer found
          companyRateCard != null ?
          companyRateCard.Hourly_Rate__c : // fallback to rack rate
          0.00; // fallback to zero if no rack rate
      }

      // Customers on subscription do not pay for Account Mangers or Technical Support Engineers
      if (onSubscription && (resource.Billing_Role__c == 'Account Manager' || resource.Billing_Role__c == 'Technical Support Engineer')) {
        billingType = 'None';
        hourlyRate = 0;
      }

      // Create new Time Entry
      timeEntries.add(new Time_Entry__c(
        Billed__c = false,
        Worklog_ID__c = worklog.tempoWorklogId,
        Resource__c = resource.Id,
        Account__c = customerId,
        Activity__c = activity,
        Role__c = resource.Billing_Role__c,
        Date_Worked__c = worklog.startDate,
        Hours__c = worklog.timeSpentSeconds / 3600,
        Hourly_Rate__c = hourlyRate,
        Hourly_Cost__c = resource.Hourly_Cost__c,
        Billing__c = billingType,
        Jira_Issue__c = worklog.issue.key,
        Notes__c = worklog.description,
        Type__c = issueFields.issuetype.name,
        Opportunity__c = getSalesforceId(issueFields.customfield_10113),
        Subject__c = issueFields.summary // max 255
      ));
    } // for

    return timeEntries;
  } // method workLogsToTimeEntries()


  // Reduces list size by removing items from end
  private static void trimList(List<Time_Entry__c> timeEntries, Integer maxSize) {
    Integer size = timeEntries.size();
    for (Integer i = size - 1; i > maxSize - 1; i--) {
      System.debug(i);
      timeEntries.remove(i);
    }
  }


  private static void upsertWorklogsToSalesforce(List<Time_Entry__c> timeEntries, List<Time_Billing_Audit__c> logEntries) {
    Time_Billing_Audit__c logEntry;
    // Attempt the upsert
    try {
      // Database.executeBatch cannot be called from within a @future method (syncTempoWorklogsToSalesforce)
      // TimeAndBillingTempoUpsert timeEntriesBatch = new TimeAndBillingTempoUpsert(timeEntries);
      // Id batchId = Database.executeBatch(timeEntriesBatch);

      trimList(timeEntries, 10000 - DML_ROW_BUFFER);

      upsert timeEntries Worklog_ID__c; // Non-batched way
      String msg = 'Upserted ' + String.valueOf(timeEntries.size()) + ' time entries';
      logEntry = createLogEntry('Salesforce: Upsert Time Entries', 'Success', msg, null, JSON.serializePretty(timeEntries));
      logEntries.add(logEntry);
      System.debug(msg);
    } catch (Exception eUpsertTimeEntries) {
      String msg = 'Did not upsert ' + String.valueOf(timeEntries.size()) + ' time entries. ';
      logEntry = createLogEntry('Salesforce: Upsert Time Entries', 'Failure',
        msg, null, JSON.serializePretty(timeEntries));
      logEntries.add(logEntry);
      System.debug(msg + eUpsertTimeEntries.getStackTraceString());
    }
  }


  // GET calls to Zendesk API
  private static HttpResponse zendeskApi(String endpoint) {
    String uri = ZENDESK_ENDPOINT + endpoint;
    HttpRequest request = setupHttpRequest('GET', uri);
    return new Http().send(request);
  }


  // Retrieves Zendesk tickets using multiple requests adding tickets to list provided as a parameter
  private static List<ZendeskTicket> getSolvedTicketsFromZendesk(DateTime syncDate, List<Time_Billing_Audit__c> logEntries) {
    List<ZendeskTicket> tickets = new List<ZendeskTicket>();
    String rawQuery = 'type:ticket solved>=' + syncDate.format('yyyy-MM-dd', 'GMT');
    String query = EncodingUtil.urlEncode(rawQuery, 'UTF-8');
    String nextPage = '/search.json?query=' + query;

    try {
      do {
        HttpResponse response = zendeskApi(nextPage);
        if (response.getStatusCode() != 200) {
          throw new ZendeskException('Error: could not connect to Zendesk to get solved tickets. Status Code: ' + String.valueOf(response.getStatusCode()));
        }

        // Deserialize response
        ZendeskTicketsFound ticketsFound = (ZendeskTicketsFound) JSON.deserialize(response.getBody(), ZendeskTicketsFound.class);

        // Add tickets to bigger list
        tickets.addAll(ticketsFound.results);

        // Strip base URI from next page if it's not null
        nextPage = ticketsFound.next_page != null ? nextPage = ticketsFound.next_page.replace(ZENDESK_BASE_URI,'') : null;
      } while (nextPage != null);
    } catch (Exception eZendeskTickets) {
      Time_Billing_Audit__c logEntry = createLogEntry('Zendesk: Get Solved Tickets', 'Failure',
        eZendeskTickets.getMessage(), null, null);
      logEntries.add(logEntry);
      throw new ZendeskException(eZendeskTickets);
    }

    return tickets;
  }


  // Retrieves Zendesk Organizations and populates parameter (map)
  private static Map<Long,String> getOrganizationsFromZendesk() {
    Map<Long,String> orgNamesMap = new Map<Long,String>();
    String nextPage = '/search.json?query=type:organization';

    // Request each page of 100 organizations until next page is null
    do {
      HttpResponse response = zendeskApi(nextPage);
      if (response.getStatusCode() != 200) {
        throw new ZendeskException('Error: could not connect to Zendesk to get organizations. Status Code: ' + String.valueOf(response.getStatusCode()));
      }

      // Deserialize results
      ZendeskOrganizationsFound organizationsFound = (ZendeskOrganizationsFound) JSON.deserialize(response.getBody(), ZendeskOrganizationsFound.class);

      // Populate the map (parameter passed by reference)
      for (ZendeskOrganization zendeskOrg: organizationsFound.results) {
        orgNamesMap.put(zendeskOrg.id, zendeskOrg.name);
      }
      nextPage = organizationsFound.next_page != null ? organizationsFound.next_page.replace(ZENDESK_BASE_URI,'') : null;
    } while (nextPage != null);

    return orgNamesMap;
  }


  // Create map for easy access to custom fields in Zendesk (array with elements that might not always be in same order) 
  private static Map<String,String> getCustomFieldsFromZendesk(ZendeskTicket zendeskTicket) {
    Map<String,String> customFieldMap = new Map<String,String>();
    for (ZendeskCustomField customField: zendeskTicket.custom_fields) {
      // APEX switch statements can only deal with enums, not Longs in a constant (no idea why)
      if (customField.id == ZENDESK_SECONDS_FIELD) customFieldMap.put('seconds', customField.value);
      if (customField.id == ZENDESK_TYPE_FIELD) customFieldMap.put('type', customField.value);
      // Ignore all other custom fields
    }

    return customFieldMap;
  }


  // Populate agentsMap (key = Zendesk user ID, value = email) - static, must populate parameter passed by reference as statics can't handle SObject types
  private static Map<Long,String> getAgentEmailsFromZendesk() {
    String nextPage = '/users.json?role[]=admin&role[]=agent';
    Map<Long,String> agentsMap = new Map<Long,String>();

    // Request each page of 100 users until next page is null
    do {
      HttpResponse response = zendeskApi(nextPage);
      if (response.getStatusCode() != 200) {
         throw new ZendeskException('Error: could not connect to Zendesk to get list of agents. Status Code: ' + String.valueOf(response.getStatusCode()));
      } // if

      // Deserialize results
      ZendeskAgentsFound agentsFound = (ZendeskAgentsFound) JSON.deserialize(response.getBody(), ZendeskAgentsFound.class);

      // Populate the map
      for (ZendeskAgent agent: agentsFound.users) {
        agentsMap.put(agent.id, agent.email);
      }

      nextPage = agentsFound.next_page != null ? agentsFound.next_page.replace(ZENDESK_BASE_URI,'') : null;
    } while (nextPage != null);

    return agentsMap;
  }


  // Populate map of resources (key = email, value = Contact) - static, log entries passed by ref
  private static Map<String,Contact> getResourcesFromSalesforce(List<Time_Billing_Audit__c> logEntries) {
    Map<String,Contact> resourcesMap = new Map<String,Contact>();
    List<Contact> resources = [SELECT Id, Email, Name, Billing_Role__c, Hourly_Cost__c FROM Contact WHERE Account.Name = :COMPANY_ACCOUNT_NAME];
    for (Contact resource: resources) {
      resourcesMap.put(resource.Email, resource);
      String warningMessage = resource.Hourly_Cost__c == null ? resource.Name + ' does not have an Hourly Cost. Please add this to their Contact record. ' : '';
      warningMessage += resource.Billing_Role__c == null ? resource.Name + ' does not have a Billing Role. Please add this to their Contact record.' : warningMessage;

      if (warningMessage != '') {
        Time_Billing_Audit__c logEntry = createLogEntry('Salesforce: Resource Cost and Role Lookup', 'Warning',
          warningMessage, JSON.serializePretty(resource), null);
        logEntries.add(logEntry);
        System.debug(logEntry);
      }
    }

    return resourcesMap;
  }


  // Create map (key = Account.Name, value = Account) of customers in Salesforce
  private static Map<String,Account> getAccountsMapFromSalesforce() {
    // Create list of customers and Map of key=Name, value=Id
    List<Account> accounts = getCustomersFromSalesforce();
    Map<String,Account> customersMap = new Map<String,Account>();
    for (Account account: accounts) {
      customersMap.put(account.Name, account);
    }

    return customersMap;
  }


  // Called by scheduled job
  @future(callout=true)
  public static void syncTempoToSalesforce(DateTime syncDate) {
    // Setup logging
    List<Time_Billing_Audit__c> logEntries = new List<Time_Billing_Audit__c>();

    List<Time_Entry__c> timeEntries;

    // Run everything in a try/catch to ensure we do not lose log entries
    try {
      // Get Tempo worklogs
      List<TempoWorklog> tempoWorklogs = getWorklogsFromTempo(syncDate, logEntries);
      timeEntries = workLogsToTimeEntries(syncDate, tempoWorklogs, logEntries);
      upsertWorklogsToSalesforce(timeEntries, logEntries);
      // updateHoursActual();
      // Insert any logEntries accumulated
      System.debug('Inserted ' + String.valueOf(timeEntries.size()) + ' time entries. Now inserting ' + String.valueOf(logEntries.size()) + ' log entries.');
      insert logEntries;
    } catch (Exception eUpsertWorklogs) {
      System.debug(eUpsertWorklogs.getMessage());
      System.debug(eUpsertWorklogs.getStackTraceString());
    }
  }


  // Create Map (key = Account.Id, value = List of Entitlements for that account)
  private static Map<ID,List<Entitlement__c>> getEntitlementsMap(Date asOfDate) {
    // List of entitlements relevant as of last month (as this is evaluated during invoice generation)
    List<Entitlement__c> entitlements = [
      SELECT Id, Account__c, Period__c, Hours__c, Starts__c, Ends__c, Hours_Used__c, Hours_Remaining__c
      FROM Entitlement__c
      WHERE Starts__c <= :asOfDate AND Ends__c >= :asOfDate
      ORDER BY Account__c, Starts__c
    ];
    Map<ID,List<Entitlement__c>> entitlementsMap = new Map<ID,List<Entitlement__c>>();
    ID currentAccountId = null;
    List<Entitlement__c> currentAccountEntitlements = new List<Entitlement__c>();
    for (Entitlement__c entitlement: entitlements) {
      if (currentAccountId != entitlement.Account__c) {
        currentAccountId = entitlement.Account__c;
        currentAccountEntitlements = new List<Entitlement__c>();
        entitlementsMap.put(currentAccountId, currentAccountEntitlements);
      }
      currentAccountEntitlements.add(entitlement);
    }

    return entitlementsMap;
  }


  // Return the entitlement for account and checked date
  private static Entitlement__c getCurrentEntitlement(Map<ID,List<Entitlement__c>> entitlementsMap, ID accountId, Date dateToCheck) {
    List<Entitlement__c> entitlements = (List<Entitlement__c>) entitlementsMap.get(accountId);
    if (entitlements == null) return null;
    for (Entitlement__c entitlement : entitlements) {
      if (dateToCheck >= entitlement.Starts__c && dateToCheck <= entitlement.Ends__c) return entitlement;
    }
    return null;
  }


  // Called by Apex scheduled job - inserts and updates Accounts in Tempo from Salesforce
  @future(callout=true) // asynchronous
  public static void syncSalesforceAccountsToTempo() { 
    // Setup logging
    List<Time_Billing_Audit__c> logEntries = new List<Time_Billing_Audit__c>();
    Time_Billing_Audit__c logEntry;

    // Create map of Tempo accounts translated to Salesforce Account.Id and Account.Name
    Map<ID,String> tempoAccountsMap = getAccountNameFromTempoAccountId(logEntries);

    // Create map (key = email, value = Jira user)
    Map<String,JiraUser> jiraEmailsMap = getUsersMapFromJira('emailAddress', logEntries);

    // Generate list of Salesforce Accounts to add vs. update (as Tempo lacks upsert in their API)
    List<Account> accounts = getCustomersFromSalesforce();

    try {
      // See if Salesforce Accounts are in Tempo, post if not
      for (Account account: accounts) {
        JiraUser jiraUser = (JiraUser) jiraEmailsMap.get(account.Owner.Email);
        String jiraAccountId = jiraUser != null ? jiraUser.accountId : JIRA_DEFAULT_OWNER_ID;
        String tempoAccountName = tempoAccountsMap.get(account.Id);

        if (tempoAccountName == null) { // account not yet in Tempo, POST
          // Insert account into Tempo
          syncAccountToTempo('POST', account, jiraAccountId);

          // Log success
          if (account != null) {
            logEntry = createLogEntry('Tempo: Insert Account', 'Success',
              'Added ' + account.Name + ' to Tempo.', null, JSON.serializePretty(account));
          } else {
            System.debug('syncSalesforceAccountsToTempo():1508 - Account is null');
          }
          logEntries.add(logEntry);
        } else if (account.Name != tempoAccountName) { // account in Tempo but has different name, PUT
          // Update account in Tempo
          syncAccountToTempo('PUT', account, jiraAccountId);

          // Log success
          logEntry = createLogEntry('Tempo: Rename Account', 'Success',
            'Tempo Account "' + tempoAccountName + '" renamed to "' + account.Name + '" to match Salesforce.', tempoAccountName, account.Name);
          logEntries.add(logEntry);
        }
      } // for
    } catch (Exception eUpsertAccounts) {
      logEntry = createLogEntry('Tempo: Upsert Accounts', 'Failure',
        String.valueOf(eUpsertAccounts.getMessage()), null, null);
      logEntries.add(logEntry);
    }

    // Log success
    String accountsInserted = JSON.serializePretty(accounts); // to prevent error if serialized JSON is long
    String msg = 'Synchronized ' + String.valueOf(accounts.size()) + ' Salesforce Customer Accounts with Tempo.';
    logEntry = createLogEntry('Salesforce: Synchronization to Tempo Accounts', 'Success', msg,
      null, accountsInserted);
    logEntries.add(logEntry);
    System.debug(msg);

    // Save any log entries in a batch
    insert logEntries;
  } // method syncSalesforceAccountsToTempo()


  // Called by scheduled job to get Zendesk solved tickets and create Time Entry records daily
  @future(callout=true)
  public static void syncZendeskToSalesforce(DateTime syncDate) {
    // Setup logging
    List<Time_Billing_Audit__c> logEntries = new List<Time_Billing_Audit__c>();
    Time_Billing_Audit__c logEntry;
      
    Map<Long,String> agentsEmailsMap;
    Map<Long,String> organizationNamesMap;
    List<ZendeskTicket> zendeskTickets;

    // REST Callouts to Zendesk
    try {
      // Create map with key = Zendesk User Id, value = Email (not log-worthy)
      agentsEmailsMap = getAgentEmailsFromZendesk();

      // Create map of organizations from Zendesk via REST Callout (not log-worthy)
      organizationNamesMap = getOrganizationsFromZendesk();

      // Create list of Zendesk Tickets via REST Callout
      zendeskTickets = getSolvedTicketsFromZendesk(syncDate, logEntries);
    } catch (ZendeskException eZendesk) {
      String zendeskError = eZendesk.getMessage();
      System.debug(zendeskError);
      logEntry = createLogEntry('Zendesk: REST Callout', 'Failure', zendeskError, null, null);
      logEntries.add(logEntry);
      insert logEntries;
      return;
    }

    // Create map of resources (pass logEntries by ref)
    Map<String,Contact> resourcesMap = getResourcesFromSalesforce(logEntries);
    
    // Create list of customers and Map of key=Name, value=Account (not log-worthy)
    Map<String,Account> customersMap = getAccountsMapFromSalesforce();

    // Customer and rack rate card lookup (not log-worthy)
    Map<String, Rate__c> ratesMap = (Map<String, Rate__c>) getRatesFromSalesforce();
    ID companyId = getCompanyId(); // Get Utilant ID for rack rate lookup

    // List of Time Entries to upsert
    List<Time_Entry__c> timeEntries = new List<Time_Entry__c>();

    // Loop through Zendesk tickets and upsert to Time Entries
    for (ZendeskTicket zendeskTicket: zendeskTickets) {
      // Create map of custom fields then assign to variables
      Map<String,String> customFields = getCustomFieldsFromZendesk(zendeskTicket);

      // Lookup resource (Contact) for Zendesk ticket using email address (looked up from assignee_id)
      String zendeskUserEmail = (String) agentsEmailsMap.get(zendeskTicket.assignee_id);
      Contact resource = (Contact) resourcesMap.get(zendeskUserEmail);

      // if resource not found, email address on their Salesforce Contact may not match their Zendesk email
      if (resource == null) {
        logEntry = createLogEntry('Salesforce: Find Resource for Zendesk Ticket', 'Warning',
          'There is no Contact record for a Zendesk Technical Support agent with the email address: ' + zendeskUserEmail + '. Please create a Contact record for this user or add this email address to an existing user.',
          JSON.serializePretty(resource), null);
        logEntries.add(logEntry);
        System.debug(logEntry);
        continue;
      }

      // Missing billing role for the resource (Contact) is also a problem
      if (resource.Billing_Role__c == null) {
        logEntry = createLogEntry('Salesforce: Find Resource Billing Role for Zendesk Ticket', 'Warning',
          'There is no Billing Role for ' + resource.Name + '. Please ensure this user has a valid Billing Role.',
          JSON.serializePretty(resource), null);
        logEntries.add(logEntry);
        System.debug(logEntry);
        continue;
      }

      // Date worked and hours calculations
      String secondsString = (String) customFields.get('seconds');
      Decimal seconds = secondsString != null ? Decimal.valueOf(secondsString): 0.00;
      Decimal hours = seconds / 3600;
      Date dateWorked = date.newinstance(
        zendeskTicket.updated_at.year(),
        zendeskTicket.updated_at.month(),
        zendeskTicket.updated_at.day()
      );

      // Lookup Salesforce Name from Zendesk id, Salesforce Id from Salesforce Name
      String customerName = (String) organizationNamesMap.get(zendeskTicket.organization_id);
      Account customer = (Account) customersMap.get(customerName);
      ID customerId = customer != null ? customer.Id : SUPPORT_NO_CUSTOMER;
      Boolean notOnSubscription = customer != null && customer.Not_on_subscription__c ? true : false;

      // Determine hourly rate for role (check customer, then company/rack rates, then zero)
      Decimal hourlyRate = 0;
      if (notOnSubscription) {
        Rate__c rateCard = (Rate__c) ratesMap.get(String.valueOf(customerId) + resource.Billing_Role__c);
        Rate__c companyRateCard = (Rate__c) ratesMap.get(String.valueOf(companyId) + resource.Billing_Role__c);
        hourlyRate = rateCard != null ?
          rateCard.Hourly_Rate__c : // if rate card for customer found
          companyRateCard != null ?
          companyRateCard.Hourly_Rate__c : // fallback to rack rate
          0.00; // fallback to zero if no rack rate
      }

      // Conditions for ticket types
      String ticketType = (String) customFields.get('type');
      ticketType = ticketType == null ? 'Question' : ticketType.capitalize(); // sometimes blank due to mistake by Support Engineer
      // BUG: Tempo currently removes spaces from what it sends over. Once they fix that, the next line will need to be fixed.
      String activity = ZENDESK_NONBILLABLE_TYPES.contains(ticketType) ? 'DefectResolution' : 'TechnicalSupport';

      // Determine Billing
      String billingType = 'Subscription';
      if (activity == 'TechnicalSupport' && notOnSubscription) billingType = 'Hourly';
      else if (activity == 'DefectResolution' || customerId == SUPPORT_NO_CUSTOMER) billingType = 'None';

      // Set non-billable time entries to have a $0 hourly rate (even though invoicing skips them) so revenue roll-ups in Salesforce are easier
      if (billingType == 'None') {
        hourlyRate = 0;
      }

      // Prepend the ticket type in front of the ticket's subject
      String notes = ticketType + ': ' + zendeskTicket.subject;

      // Add Time Entry using Zendesk Ticket info
      Time_Entry__c timeEntry = new Time_Entry__c(
        Account__c = customerId,
        Activity__c = activity,
        Date_Worked__c = dateWorked,
        Hours__c = hours,
        Resource__c = resource.Id,
        Role__c = resource.Billing_Role__c,
        Hourly_Cost__c = resource.Hourly_Cost__c,
        Hourly_Rate__c = hourlyRate,
        Billing__c = billingType,
        Notes__c = notes,
        Zendesk_Ticket__c = zendeskTicket.id,
        Type__c = ticketType,
        Subject__c = zendeskTicket.subject
      );
      timeEntries.add(timeEntry);
    } // for each Zendesk ticket

    upsert timeEntries Zendesk_Ticket__c; // Zendesk Ticket is External ID

    // Log success
    String ticketsImported = JSON.serializePretty(timeEntries); // Cannot do this as parameter to createLogEntry or errors
    // if we provide JSON.serializePretty(timeEntries) as the last parameter even though it's only 118,689 characters (max is 6m), we get an error so put in a variable instead
    String msg = 'Retrieved list of solved tickets and created ' + String.valueOf(timeEntries.size()) + ' time entries.';
    logEntry = createLogEntry('Zendesk: Synchronization to Salesforce', 'Success',
      msg, null, ticketsImported);
    logEntries.add(logEntry);
    System.debug(msg);

    insert logEntries;
  } // method syncZendeskToSalesforce()


  // Update Time Entries to link to Opportunities
  @future
  public static void timeEntryToOpportunity(Date fromDate, Date toDate) {
    List<Opportunity> opportunities = [SELECT Id, Jira_Issue__c FROM Opportunity];
    Map<String,ID> opportunityMap = new Map<String,ID>();
    for (Opportunity thisOp : opportunities) {
      String jiraIssue = thisOp.Jira_Issue__c;
      if (jiraIssue != null) opportunityMap.put(thisOp.Jira_Issue__c.toUpperCase(), thisOp.Id);
    }
    List<Time_Entry__c> timeEntries = [SELECT Id, Jira_Issue__c, Opportunity__c FROM Time_Entry__c WHERE Date_Worked__c >= :fromDate AND  Date_Worked__c <= :toDate];
    for (Time_Entry__c timeEntry: timeEntries) {
      if (timeEntry.Jira_Issue__c != null) {
        ID oppId = (ID) opportunityMap.get(timeEntry.Jira_Issue__c.toUpperCase());
        if (oppId != null) timeEntry.Opportunity__c = oppId;
      }
    }
    update timeEntries;
  }


  // Update Opportunity Hours (Actual) from Time Entries
  @future
  public static void updateHoursActual() {
    AggregateResult[] groupedResults = [
      SELECT SUM(Hours__c), Opportunity__c
      FROM Time_Entry__c
      WHERE Billing__c != 'None' AND Opportunity__c != null
      GROUP BY Opportunity__c
    ];
    List<Opportunity> opportunities = new List<Opportunity>();
    for (AggregateResult ar : groupedResults) {
      Opportunity opportunity = new Opportunity(
        Id = (ID) ar.get('Opportunity__c'),
        Hours_Actual__c = (Decimal) ar.get('expr0')
      );
      opportunities.add(opportunity);
    }
    update opportunities;
  }


  // Return list of Time Entries not billed that are billable on an hourly basis (or deduct from burndown)
  private static List<SObject> getUnbilledTimeEntries(Date endDate, String customerType) {
    return [
      SELECT Id, Account__c, Resource__c, Role__c, Hourly_Cost__c, Hourly_Rate__c, Date_Worked__c, Hours__c,
        Notes__c, Billing__c, Billed__c, Jira_Issue__c, Zendesk_Ticket__c, Worklog_ID__c,
        Account__r.Name, Account__r.c2g__CODASalesTaxStatus__c, Account__r.Platform__c,
        Account__r.Not_on_subscription__c, Type__c, Subject__c, Opportunity__c
      FROM Time_Entry__c
      WHERE
        Billed__c = false AND Billing__c = 'Hourly' AND Date_Worked__c <= :endDate AND
        Account__r.Platform__c = :customerType AND Account__r.Type = 'Customer'
      ORDER BY Account__r.Name, Role__c, Date_Worked__c
    ];
  }


  // Create FinancialForce Sales Invoice with sensible defaults
  private static c2g.CODAAPIInvoiceTypes_10_0.Invoice createNewSalesInvoice(Date endDate, ID accountId, String accountName){
    // Instantiate a new Sales Invoice
    c2g.CODAAPIInvoiceTypes_10_0.Invoice salesInvoice = new c2g.CODAAPIInvoiceTypes_10_0.Invoice();
    
    // Associate Sales Invoice with Account
    c2g.CODAAPICommon.Reference accountRef = new c2g.CODAAPICommon.Reference();
    accountRef.Id = accountId;
    accountRef.Name = accountName;
    salesInvoice.Account = accountRef;

    // Set various properties
    c2g.CODAAPICommon.Reference currencyRef = new c2g.CODAAPICommon.Reference(); // https://help.financialforce.com/accounting-api-apex/2020.2/CODAAPICommon.htm#Reference
    currencyRef.Name = CURRENCY_NAME;
    salesInvoice.InvoiceCurrency = currencyRef;
    salesInvoice.InvoiceDate = endDate;
    salesInvoice.DeriveDueDate = true;
    salesInvoice.InvoiceStatus = c2g.CODAAPIInvoiceTypes_10_0.enumInvoiceStatus.InProgress; // https://help.financialforce.com/accounting-api-apex/2020.2/CODAAPIInvoiceTypes_10_0.htm#enumInvoiceStatus

    // Attach line item lists
    c2g.CODAAPIInvoiceLineItemTypes_10_0.InvoiceLineItems lineItemsWrapper = new c2g.CODAAPIInvoiceLineItemTypes_10_0.InvoiceLineItems(); // https://help.financialforce.com/accounting-api-apex/2020.2/CODAAPIInvoiceLineItemTypes_10_0.htm#InvoiceLineItems
    List<c2g.CODAAPIInvoiceLineItemTypes_10_0.InvoiceLineItem> lineItems = new List<c2g.CODAAPIInvoiceLineItemTypes_10_0.InvoiceLineItem>();
    lineItemsWrapper.LineItemList = lineItems;
    salesInvoice.LineItems = lineItemsWrapper;

    return salesInvoice;
  }


  // Adds new invoice line item with sensible defaults  
  private static c2g.CODAAPIInvoiceLineItemTypes_10_0.InvoiceLineItem createNewLineItem(String dimensionName, String description, Decimal hourlyRate) {
    c2g.CODAAPIInvoiceLineItemTypes_10_0.InvoiceLineItem lineItem = new c2g.CODAAPIInvoiceLineItemTypes_10_0.InvoiceLineItem();
    c2g.CODAAPICommon.Reference dimensionRef = new c2g.CODAAPICommon.Reference();
    dimensionRef.Name = dimensionName; // Carrier or Vendor
    lineItem.Dimension1 = dimensionRef;
    c2g.CODAAPICommon.Reference productRef = new c2g.CODAAPICommon.Reference();
    productRef.Name = SERVICE_PRODUCT;
    lineItem.Product = productRef;
    lineItem.LineDescription = description;
    lineItem.Quantity = 0;
    lineItem.UnitPrice = hourlyRate; // FinancialForce errors if scale not 9

    return lineItem;
  }


  // Used by BulkCreateInvoice()
  private static c2g.CODAAPICommon_10_0.Context createCompanyContext() {
    c2g.CODAAPICommon_10_0.Context ctx = new c2g.CODAAPICommon_10_0.Context(); // https://help.financialforce.com/accounting-api-apex/2020.2/CODAAPICommon_10_0.htm#Context
    ctx.CompanyName = COMPANY_ACCOUNT_NAME; // not required for single-company implementations of FFA
    return ctx;
  }


  // Bulk creates invoices and invoice line items from unbilled time entries (anything unbilled gets billed regardless of time period).
  @future(callout=true)
  public static void generateHourlyInvoices(Date endDate, String customerType) {
    // List of time entries sorted by Account, Role, Date Worked (cast required as static methods cannot return lists of specific SObject)
    List<Time_Entry__c> timeEntries = (List<Time_Entry__c>) getUnbilledTimeEntries(endDate, customerType);

    // Bail out if no Time Entries to bill
    if (timeEntries.size() == 0) {
      System.debug('No ' + customerType + ' time entries to invoice.');
      return;
    }

    // Billable Time Entries to be inserted for portion over an entitlement
    List<Time_Entry__c> splitTimeEntries = new List<Time_Entry__c>();

    // Setup logging
    List<Time_Billing_Audit__c> logEntries = new List<Time_Billing_Audit__c>();
    Time_Billing_Audit__c logEntry;

    // Used in loop
    List<c2g.CODAAPIInvoiceTypes_10_0.Invoice> salesInvoices = new List<c2g.CODAAPIInvoiceTypes_10_0.Invoice>(); // https://help.financialforce.com/accounting-api-apex/2020.2/CODAAPIInvoiceTypes_10_0.htm#Invoice
    c2g.CODAAPIInvoiceTypes_10_0.Invoice salesInvoice;
    c2g.CODAAPIInvoiceLineItemTypes_10_0.InvoiceLineItem lineItem;
    Entitlement__c thisEntitlement;

    // Entitlements.Hours_Used__c updated as billed Time Entries burn off hours
    List<Entitlement__c> entitlements = new List<Entitlement__c>();

    // Build map with key = Account.Id, value = List<Entitlement__c>
    Map<ID,List<Entitlement__c>> entitlementsMap = getEntitlementsMap(endDate);

    // Initial values
    ID currentAccountId = null;
    String currentRole = null;
    Decimal entitlementRemaining;

    // Loop through unbilled Hourly timeEntries ordered by Account, Role, Date Worked
    for (Time_Entry__c timeEntry: timeEntries) {
      // if Account has no Sales Tax Status, log then skip to the next entry (time entry will get picked up automatically once Account.Sales Tax Status is set)
      if (timeEntry.Account__r.c2g__CODASalesTaxStatus__c == null) {
        String msg = timeEntry.Account__r.Name + ' does not have a Sales Tax Status set.';
        logEntry = createLogEntry('FinancialForce: Get Sales Tax Status from Account', 'Warning',
          msg, null, JSON.serializePretty(timeEntry));
        logEntries.add(logEntry);
        System.debug(msg);
        continue; // skip to next
      }

      // Improve code readability   
      Date dateWorked = timeEntry.Date_Worked__c;
      Boolean newInvoice = currentAccountId != timeEntry.Account__c;
      Boolean newRole = currentRole != timeEntry.Role__c || newInvoice;
      Boolean onSubscription = !timeEntry.Account__r.Not_on_subscription__c;

      if (newInvoice) { // first record or different account
        salesInvoice = createNewSalesInvoice(endDate, timeEntry.Account__c, timeEntry.Account__r.Name);
        salesInvoices.add(salesInvoice);

        // Current Account's entitlement based on Date Worked (if there is one)
        thisEntitlement = getCurrentEntitlement(entitlementsMap, timeEntry.Account__c, dateWorked);

        // No entitlement: 0, Period = Month: Hours Entitled each month, Period = Year: Hours Remaining
        if (thisEntitlement == null) {
          entitlementRemaining = 0;
        } else {
          entitlementRemaining = thisEntitlement.Period__c == 'Month' ? thisEntitlement.Hours__c : thisEntitlement.Hours_Remaining__c;
          entitlements.add(thisEntitlement); // Updates to Hours_Used__c for Yearly entitlements
        }

        currentAccountId = timeEntry.Account__c; // establish current account
        System.debug('New invoice: ' + timeEntry.Account__r.Name + ', Entitlement remaining = ' + String.valueOf(entitlementRemaining));
      }

      // Create new line item for each role and roll-up hours
      if (newRole) {
        lineItem = createNewLineItem(timeEntry.Account__r.Platform__c, timeEntry.Role__c, timeEntry.Hourly_Rate__c);
        salesInvoice.LineItems.LineItemList.add(lineItem);
        currentRole = timeEntry.Role__c; // establish current role
      }

      // Handle whether the time entry is part of the burndown, partially part of the burndown, or not part of the burndown
      Boolean enough = entitlementRemaining - timeEntry.Hours__c >= 0;
      Boolean almostEnough = entitlementRemaining > 0 && !enough;

      if (enough) {
        lineItem.Quantity += timeEntry.Hours__c.setScale(2);
        lineItem.UnitPrice = 0;
        timeEntry.Hourly_Rate__c = 0; // override - covered by burndown
        entitlementRemaining -= timeEntry.Hours__c;
      } else if (almostEnough) { // split time entry and invoice line item - the first non-billable, the second billable
        // Portion that's burndown for existing invoice line item
        lineItem.Quantity += entitlementRemaining.setScale(2); // consumes amount remaining
        lineItem.UnitPrice = 0;
        Decimal portionOverEntitlement = timeEntry.Hours__c - entitlementRemaining;
        timeEntry.Hours__c = entitlementRemaining; // reduce hours on original time entry as portion will be split

        entitlementRemaining = 0; // now consumed by lineItem/timeEntry

        // Create split
        Time_Entry__c splitTimeEntry = new Time_Entry__c(
          Date_Worked__c = dateWorked,
          Account__c = timeEntry.Account__c,
          Resource__c = timeEntry.Resource__c,
          Role__c = timeEntry.Role__c,
          Hours__c = portionOverEntitlement,
          Notes__c = timeEntry.Notes__c + ' Original Worklog: ' + String.valueOf(timeEntry.Worklog_ID__c) + ', Original Zendesk Ticket: ' + String.valueOf(timeEntry.Zendesk_Ticket__c) + '.',
          Hourly_Rate__c = timeEntry.Hourly_Rate__c,
          Billed__c = true,
          Billing__c = 'Hourly',
          Entitlement__c = thisEntitlement.Id, // over entitlement - track overage
          Jira_Issue__c = timeEntry.Jira_Issue__c,
          Type__c = timeEntry.Type__c,
          Subject__c = timeEntry.Subject__c,
          Opportunity__c = timeEntry.Opportunity__c
        );
        splitTimeEntries.add(splitTimeEntry);

        timeEntry.Hourly_Rate__c = 0; // Initial time entry is burndown (delayed setting for split to pickup rate)

        // Billable invoice line item for remainder
        lineItem = createNewLineItem(timeEntry.Account__r.Platform__c, splitTimeEntry.Role__c, splitTimeEntry.Hourly_Rate__c);
        salesInvoice.LineItems.LineItemList.add(lineItem);
        lineItem.Quantity = portionOverEntitlement.setScale(2); // starting quantity for new line item
      } else { // no entitlement, not in entitlement range or ran out of entitled hours
        lineItem.Quantity += timeEntry.Hours__c.setScale(2); // FinancialForce errors if scale not 6 (oddly specific)
      }

      // Update Entitlement record (if there is one); hours remaining may go negative (but not a bug)
      if (thisEntitlement != null) {
        timeEntry.Entitlement__c = thisEntitlement.Id;
        thisEntitlement.Hours_Used__c += timeEntry.Hours__c;
      }

      // if there's at least one billable line item, flag invoice not to be deleted (note: IsDeleted is otherwise null)
      if (lineItem.Quantity > 0 && lineItem.UnitPrice > 0) salesInvoice.IsDeleted = false;

      timeEntry.Billed__c = true; // Mark Time Entry as billed
    } // for time entries

    // Reverse iterate over salesInvoices and delete zero-dollar ones.
    // If we want summaries of starting and ending balances, create $0 Sales Invoices (remove this block)
    for (Integer i = (salesInvoices.size()-1); i>= 0; i--) {
      c2g.CODAAPIInvoiceTypes_10_0.Invoice invoice = salesInvoices[i];
      if (invoice.IsDeleted == null) {
        salesInvoices.remove(i);
      }
    }

    // Bulk create invoices - https://help.financialforce.com/accounting-api-apex/2020.2/CODAAPISalesInvoice_10_0.htm#BulkCreateInvoice0
    c2g.CODAAPISalesInvoice_10_0.BulkCreateInvoice(createCompanyContext(), salesInvoices);

    // Updated Time Entries as billed and insert any splits needed
    update timeEntries;
    insert splitTimeEntries;

    // Update Entitlements to track burndown
    update entitlements;

    // Log success
    String timeEntriesInvoiced = JSON.serializePretty(timeEntries); // prevents error if serialized JSON is long
    String msg = 'Created ' + String.valueOf(salesInvoices.size()) + ' ' + customerType + ' Sales Invoices.';
    logEntry = createLogEntry('FinancialForce Accounting: Invoices from Time Entries', 'Success',
      msg, null, timeEntriesInvoiced);
    logEntries.add(logEntry);
    System.debug(msg);

    insert logEntries;
  } // method generateHourlyInvoices()

} // class TimeAndBilling