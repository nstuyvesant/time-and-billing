// Offload saving of Time_Entry__c record from TimeAndBilling.upsertWorklogsToSalesforce():824
// Can't be called from future method
public class TimeAndBillingTempoUpsert implements Database.Batchable<SObject>, Database.Stateful {

  public Integer recordsProcessed = 0;
  private List<Time_Entry__c> timeEntries = new List<Time_Entry__c>();

  public TimeAndBillingTempoUpsert(List<Time_Entry__c> timeEntriesPassed) {
    timeEntries = timeEntriesPassed;
  }

  public List<Time_Entry__c> start(Database.BatchableContext context) {
    return timeEntries;
  }

  public void execute(Database.BatchableContext context, List<Time_Entry__c> timeEntriesChunk) {
    try {
      upsert timeEntriesChunk Worklog_ID__c;
      recordsProcessed += timeEntriesChunk.size();
    } catch (Exception eUpsertTimeEntries) {
      System.debug(eUpsertTimeEntries);
      // System.debug('Fail: Upsert Time Entries ' + JSON.serializePretty(timeEntries));
    }
  }

  public void finish(Database.BatchableContext context) {
    System.debug(recordsProcessed + ' records processed.');
    AsyncApexJob job = [
      SELECT Id, Status, NumberOfErrors,
        JobItemsProcessed, TotalJobItems, CreatedBy.Email
      FROM AsyncApexJob
      WHERE Id = :context.getJobId()
    ];
    // EmailUtils.sendMessage(job, recordsProcessed);
  }
}