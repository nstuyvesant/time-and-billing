global class TimeAndBillingDaily implements Schedulable {
    global void execute(SchedulableContext ctx) {
      DateTime syncDate = System.today().addDays(-1);
      TimeAndBilling.syncTempoToSalesforce(syncDate);
      TimeAndBilling.syncZendeskToSalesforce(syncDate);
      TimeAndBilling.syncTimeEntryDeletions(syncDate);
      TimeAndBilling.syncSalesforceAccountsToTempo();
      // TimeAndBilling.setTempoActivities(); // Short list, can be manually entered, doesn't change much (if at all)
    }
}

// 1. Setup -> Apex Classes
// 2. Click Schedule Apex
// 3. Set Job Name to "Daily WorkLog Import"
// 4. Click the lookup button next to Apex class and enter TimeAndBilling* for the search term.
// 5. Select "TimeAndBillingDaily"
// 6. Select Weekly for the frequency and set to run daily (even weekends).
// 7. Select the start and end dates, and a preferred start time.
// 8. Click Save.