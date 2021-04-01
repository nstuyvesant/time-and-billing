# Product Backlog

## Bugs
- [High] If there are rates for a customer but none are used, fallback to rack rates not working (CRUM)
- [Low] Zendesk ticket import uses the "updated_at" date rather than "solved_at" because of API limitations. As we are importing daily and billing monthly, if updated_at changes, it should not affect invoicing so this is classified as low priority because of that.

## Features
- [Low] Once Tempo fixes their REST API to not strip out names for GET /work-attributes/{key}, update API names of the Activity Picklist Value Set in Salesforce
- [Medium] Refactor syncZendeskToSalesforce() to improve testability, readibility and promote DRY
- [Medium] Refactor generateInvoicesSummarized() to improve testability, readibility and promote DRY
- [Medium] Create method to check for errors in Time_Billing_Audit__c in past 24 hours and send email (daily digest of errors) to Salesforce Admins
- [Medium] Create method to call getPtoFromTempo(), GET /​hr/​v2/​workers then POST to ADP /time/v2/workers/{aoid}/time-off-requests. See https://developers.adp.com/articles/general/make-your-first-api-call-using-postman-1
- [Low] Synchronize Activities from Salesforce to Tempo (Salesforce is authoritative). For now, this is done manually.
- [Low] Change generateInvoicesSummarized() to use Account.Dimension 1 instead of Account.Platform. For now, Dimension 1 has not been consistently set for every account so we can't rely on it.