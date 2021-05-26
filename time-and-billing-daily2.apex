global class TimeAndBillingDaily2 implements Schedulable {
    global void execute(SchedulableContext ctx) {
      TimeAndBilling.updateHoursActual(); 
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