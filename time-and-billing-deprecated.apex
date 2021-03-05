public class TimeAndBilling {
  // Database.executeBatch cannot be called from within a @future method (syncTempoWorklogsToSalesforce)
  // TimeAndBillingTempoUpsert timeEntriesBatch = new TimeAndBillingTempoUpsert(timeEntries);
  // Id batchId = Database.executeBatch(timeEntriesBatch);

  private class TempoPlan {
    // String self;
    private Long id;
    private Date startDate;
    private Date endDate;
    private Integer secondsPerDay;
    private Boolean includeNonWorkingDays;
    private String description;
    private DateTime createdAt;
    private DateTime updatedAt;
    private TempoType assignee;
    private TempoType planItem;
    private TempoRecurrence recurrence;
    private TempoDates dates;
  }

  private class TempoPlans extends TempoDownload {
    private TempoPlan[] results;
  }

  private static final String ADP_ENDPOINT = 'callout:ADP';
  private static final String NOTIFICATION_SUBJECT = 'Utilant Integration Exception';
  private static final String PUBLIC_GROUP = 'Salesforce Administration';
  private static final String TEMPO_PTO_ISSUE = 'https://utilant.atlassian.net/rest/api/2/issue/UT-1';


  // Return date in d-MMM-yyyy format
  private static String dMMMyyyy(Date d) {
    Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day());
    return dt.format('d-MMM-yyyy');
  }


  // Get list of email addresses for members of a Public Group
  private static List<String> getEmailAddresses() {
    List<String> idList = new List<String>();
    List<String> mailToAddresses = new List<String>();
    Group g = [SELECT (SELECT userOrGroupId FROM groupMembers) FROM group WHERE name = :PUBLIC_GROUP];
    if (g.groupMembers.size() == 0) throw new TimeAndBillingException('The group, ' + PUBLIC_GROUP + ', must have at least one member.');
    for (GroupMember gm: g.groupMembers) {
      idList.add(gm.userOrGroupId);
    }
    User[] usr = [SELECT email FROM user WHERE id IN :idList];
    for(User u : usr) {
      mailToAddresses.add(u.email);
    }
    return mailToAddresses;
  }


  // Send email to a Salesforce Public Group named "Salesforce Administration"
  private static void notifyAdmin(String subject, String message) {
    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(getEmailAddresses());
    mail.setSubject(subject);
    mail.setPlainTextBody(message);
    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
  }

  // Support dynamic updates of Activities from Salesforce to Tempo
  // While this can be done using Tempo's old API, it's not worth the
  // effort until they support PUT /work-attributes/{key}
  // Old API looks like this but it's a pain because authentication is different and all the items have IDs to keep track of.
  // GET https://app.tempo.io/rest/tempo-core/1/work-attribute/value/4
  // PUT https://app.tempo.io/rest/tempo-core/1/work-attribute/4/static-list-value/5
  private static String[] getAttributesFromTempo() {
    HttpResponse response = tempoApi('GET', TEMPO_CORE_API, '/work-attributes/_Activity_', '');

    if (response.getStatusCode() != 200) {
      throw new TempoException('Error: could not connect to Tempo to get Activities. Status Code: ' + String.valueOf(response.getStatusCode()));
    }

    String jsonBody = response.getBody();
    TempoActivities activities = (TempoActivities) JSON.deserialize(jsonBody, TempoActivities.class);
    return activities.values;
  }


  // Creates JSON array from Activity picklist value set in Salesforce
  private static String getActivitiesFromSalesforce() {
    Schema.DescribeFieldResult F = Time_Entry__c.Activity__c.getDescribe();
    Schema.sObjectField T = F.getSObjectField();
    List<PicklistEntry> activities = T.getDescribe().getPicklistValues();
    String jsonArray = '[';
    for (PicklistEntry activity: activities) {
      jsonArray += '"' + activity.getLabel() + '",';
    }
    jsonArray += jsonArray.removeEnd(',') + ']';
    return jsonArray;
  }


  // Upsert Activities to Tempo
  @future(callout = true)
  private static void sendActivitiesToTempo(string jsonString) {
    System.debug('Placeholder for sending the Activities list to Tempo.');
    // TODO: Would have to use https://www.tempo.io/server-api-documentation/core#operation/updateStaticListValue
  }


  // Called by scheduled job to update Tempo's Activity picklist daily
  public static void setTempoActivities() {
    sendActivitiesToTempo(getActivitiesForTempo());
  }


  // Get PTO time from Tempo
  private static TempoPlan[] getPtoFromTempo(DateTime syncDate, Integer offset) {
    // Get PTO plan dates from Tempo plus/minus 180 days
    DateTime fromDate = syncDate.addMonths(-6);
    DateTime toDate = syncDate.addMonths(6);
    String query = '?assigneeType=USER&planItemType=ISSUE&limit=1000' +
      '&from=' + fromDate.format('yyyy-MM-dd') +
      '&to=' + toDate.format('yyyy-MM-dd') +
      '&updatedFrom=' + syncDate.format('yyyy-MM-dd') +
      '&offset=' + String.valueOf(offset);
    HttpResponse response = tempoApi('GET', TEMPO_CORE_API, '/accounts/plans' + query, null);

    // Log issue and throw error
    if (response.getStatusCode() != 200) {
      Time_Billing_Audit__c logEntry = createLogEntry('Tempo: Get PTO', 'Failure',
        'Could not connect to Tempo to get PTO plan dates. Status Code: ' + String.valueOf(response.getStatusCode()),
        null, null);
      logSingleEntry(logEntry);
      throw new TempoException(logEntry.Summary__c);
    } // if

    // Deserialize Tempo Plans 
    String jsonBody = response.getBody();
    jsonBody.replace('"from":', '"fromReserved":'); // rename from property as it is a reserved word in Apex
    TempoPlans deserializedResponse = (TempoPlans) JSON.deserialize(jsonBody, TempoPlans.class);

    // Filter out all plans except ones for PTO
    List<TempoPlan> ptoRequests = new List<TempoPlan>();
    for (TempoPlan plan: deserializedResponse.results) {
      if (plan.planItem.self == TEMPO_PTO_ISSUE) ptoRequests.add(plan);
    }
    
    return ptoRequests; // in Tempo API's format (could translate it to something friendlier)
  }


  // Check to see if code is running in Sandbox
  public static Boolean isSandbox() {
    return [select IsSandbox from Organization limit 1].IsSandbox;
  }
}