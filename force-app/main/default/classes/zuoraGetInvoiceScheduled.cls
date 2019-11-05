/**
 * Created by b.jarmolinski on 13/08/2018.
 * Scheduled class - triggered in periodic time lags, checking if there are zInvoice records without Invoice files
 * if there are any it invokes another class which processes the rest of the logic (getting files from zuora)
 *
 * Version 2.0 - 02/11/2018 by Bartosz
 * - change logic how invoices are found
 *      - BEFORE: every 15 min look for new invoices and get files for them
 *      - AFTER: get all invoice records which do not have files yet
 *
 * 22.10.2019 M.Muchow
 * - added logic to limit amount of Invoices in iList by Custom Metadata
 */

public class zuoraGetInvoiceScheduled implements Schedulable {

    public void execute(SchedulableContext sc) {

        // query custom meta data settings to get number of minute intervals for the schedules class
        zuoraSetting__mdt settings;
        // 00D24000000opic is org Id of sonnen Live org / production
        if(UserInfo.getOrganizationId() != '00D24000000opic' && UserInfo.getOrganizationId() != '00D24000000opicEAA' ) {
            settings = [SELECT ScheduledIntervals__c, LimitForQuery__c FROM zuoraSetting__mdt WHERE Label = 'Sandbox'];
        } else {
            settings = [SELECT ScheduledIntervals__c, LimitForQuery__c FROM zuoraSetting__mdt WHERE Label = 'Prod'];
        }

        // execute logic in the zuoraGetInvoice class
        findNewInvoices((Integer)settings.ScheduledIntervals__c, (Integer)settings.LimitForQuery__c);

        // remove past cron triggers
        List<cronTrigger> cronTriggers = [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE 'ZuoraInvoice%'];
        for (CronTrigger cronTrigger : cronTriggers) {
            System.abortJob(cronTrigger.Id);
        }
        
        // create new cron trigger for 15 minutes later
        DateTime dt = System.now().addMinutes((Integer)settings.ScheduledIntervals__c);

        String day = String.valueOf(dt.day());
        String month = String.valueOf(dt.month());
        String year = String.valueOf(dt.year());
        String hour = String.valueOf(dt.hour());
        String minute = String.valueOf(dt.minute());
        String second = String.valueOf(dt.second());

        String strJobName = 'ZuoraInvoice_'+year+'-'+month+'-'+day+'T'+hour+':'+minute+':'+second;
        String strSchedule = '0 '+minute+' '+hour+' '+day+' '+month+' ?';

        System.schedule(strJobName, strSchedule, new zuoraGetInvoiceScheduled());
    }
    @future(callout=true)
    public static void findNewInvoices(Integer scheduledIntervals, Integer queryLimit) {

        // find all invoice objects with or without ContentDocLink (at this moment (Winter 18) ContentDocLink cannot be included in WHERE clause)
        List<Zuora__ZInvoice__c> invoiceList = [SELECT Id, Name, Zuora__Zuora_Id__c, Zuora__BillingAccount__c,
                                                (SELECT LinkedEntityId, ContentDocument.Title FROM ContentDocumentLinks WHERE ContentDocument.Title LIKE 'INV%')
                                                FROM Zuora__ZInvoice__c ];

        List<Zuora__ZInvoice__c> iList = new List<Zuora__ZInvoice__c>();

        System.debug(invoiceList.size());
        Integer num = 0;
        for (Zuora__ZInvoice__c inv : invoiceList) {
            if (num == queryLimit) {
                break;
            } else if (inv.ContentDocumentLinks.size() == 0) {
                num = num + 1;
                iList.add(inv);
            }
        }
        System.debug('iList: '+iList.size());

        if (iList.size() > 0) {
            zuoraGetInvoice invExec = new zuoraGetInvoice(iList);
            invExec.getInvoices();
        }
    }
}