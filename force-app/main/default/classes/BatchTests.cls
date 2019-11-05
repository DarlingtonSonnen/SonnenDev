@isTest
private class BatchTests {

    static final String AREA_MANAGER_PROFILE_STRING = '* Area Manager';
    static final String DEBUG_HEADER = 'BatchTests.';

    /**
     * Tests LeadAssignPartnerAndManagerBatch
     *
     * Changelog
     *
     * Polina Tsuban-Drobot 2018-04-10 - SOBCRM-1172
     * - fixed checking WasHandledByPartnerAssignBatch__c field
     *
     * Andrey Safronenko 2018-03-09 - SOBCRM-1153
     * - Added test for handling TargetCountry__c
     *
     * 2016-12-13
     * - Added test for handling of WasHandledByPartnerAssignBatch__c and
     *   WasHandledByAreaManagerAssignBatch__c
     *
     * 2016-11-15
     * - Fix: Switched from PostalCodeArea__c.AreaManager__c to PostalCodeArea__c.OwnerId
     *
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     * @since 2016-10-11
     * @see https://interaktiv.jira.com/browse/SOBCRM-670
     */
    @isTest static void testLeadAssignPartnerAndManagerBatch() {

        String CRON_EXPRESSION = '0 0 0 15 3 ? 2022';

        String countryCode = 'de';
        String postalCode = '35578';
        Double latitude = 50.55175;
        Double longitude = 8.52257;
        Double latitude2 = 51.0;
        Double longitude2 = 9.0;
        // SOBCRM-1153 - TargetCountry__c value for Italy area
        String ITALY = 'IT';

        //----------------------------
        // Area Managers
        //----------------------------
        // Create an Area Manager which is a normal User
        Id idProfile = AssignDelegate.getAreaManagerProfileId();

        List<User> listAreaManagers = new List<User>();

        // This one will be related to a PostalCodeArea
        listAreaManagers.add(new User(
                Alias = 'AM1',
                Email = 'test@foobar.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Bogusman',
                LanguageLocaleKey = 'en_US',
                Latitude = latitude,
                Longitude = longitude,
                LocaleSidKey = 'en_US',
                TimeZoneSidKey='America/Los_Angeles',
                ProfileId = idProfile,
                // Try to be unique and creative over all Salesforce Orgs in the whole universe
                UserName='bogusman@tri-tra-trullala-der-sonnen-area-manager-ist-wieder.da'
        ));
        // This one should be found via geolocation
        listAreaManagers.add(new User(
                Alias = 'AM2',
                Email = 'test@foobar.com',
                EmailEncodingKey = 'UTF-8',
                Latitude = latitude2,
                Longitude = longitude2,
                LastName = 'Voidster',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey='America/Los_Angeles',
                ProfileId = idProfile,
                // Try to be unique and creative over all Salesforce Orgs in the whole universe
                UserName='voidster@tri-tra-trullala-der-sonnen-area-manager-ist-wieder.da'
        ));
        insert listAreaManagers;

        //----------------------------
        // Partner Accounts
        //----------------------------
        // Add some Accounts
        Map<String,Id> recordTypesAccount = SonnenbatterieConstants.getRecordTypeIdsByObjectName('Account');

        List<Account> listAccounts = new List<Account>();

        listAccounts.add(new Account(
                Name = 'Supplier',
                RecordTypeId = recordTypesAccount.get('Supplier'),
                Status__c = 'active',
                BillingLatitude = latitude,
                BillingLongitude = longitude
        ));
        listAccounts.add(new Account(
                Name = 'SBC 1',
                RecordTypeId = recordTypesAccount.get('SBC'),
                Status__c = 'active',
                BillingLatitude = latitude,
                BillingLongitude = longitude
        ));
        listAccounts.add(new Account(
                Name = 'SBC 2',
                RecordTypeId = recordTypesAccount.get('SBC'),
                Status__c = 'active',
                BillingLatitude = latitude2,
                BillingLongitude = longitude2
        ));
        insert listAccounts;

        //----------------------------
        // PostalCodeAreas
        //----------------------------
        PostalCodeArea__c oPostalCodeArea = new PostalCodeArea__c(
                Name = postalCode,
                Country__c = countryCode,
                AssignedPartner__c = listAccounts.get(1).Id,
                OwnerId = listAreaManagers.get(0).Id
        );
        insert oPostalCodeArea;

        //----------------------------
        // Leads
        //----------------------------
        // Lead
        List<Lead> listLeads = new List<Lead>();

        // Should find its Partner (listAccounts.get(1).Id) and
        // Manager by PostalCodeArea (listAreaManagers.get(0).Id)
        listLeads.add(new Lead(
            FirstName = 'Void',
            LastName = 'Bogusman',
            // should be used
            PostalCode = postalCode,
            CountryCode = countryCode,
            // should NOT be used
            Latitude = latitude,
            Longitude = longitude
        ));
        // Should find its Partner (listAccounts.get(2)) and
        // Manager (listAreaManagers.get(1)) by geolocation
        listLeads.add(new Lead(
            FirstName = 'Bugs',
            LastName = 'Bunny',
            // should NOT be used
            PostalCode = '12345',
            CountryCode = countryCode,
            // should be used
            Latitude = latitude2,
            Longitude = longitude2
        ));
        // Should find its Partner (listAccounts.get(2))
        // with remaining Manager due to WasHandledByAreaManagerAssignBatch__c
        // and set AreaManager__c
        listLeads.add(new Lead(
            FirstName = 'Hans',
            LastName = 'Meiser',
            // should NOT be used
            PostalCode = '12345',
            CountryCode = countryCode,
            // should be used
            Latitude = latitude2,
            Longitude = longitude2,
            WasHandledByAreaManagerAssignBatch__c = TRUE,
            AreaManager__c = listAreaManagers.get(0).Id
        ));
        // Should find its Manager (listAreaManagers.get(1)) by geolocation
        // with remaining Partner due to WasHandledByPartnerAssignBatch__c and
        // set AssignedSBC__c
        listLeads.add(new Lead(
            FirstName = 'Hugo',
            LastName = 'Hansen',
            // should NOT be used
            PostalCode = '12345',
            CountryCode = countryCode,
            // should be used
            Latitude = latitude2,
            Longitude = longitude2,
            WasHandledByPartnerAssignBatch__c = TRUE,
            AssignSBC__c = listAccounts.get(1).Id // SBC 1
        ));
        // SOBCRM-1153
        // Should not assign a Recommended Partner because TargetCountry is Italy
        // Should assign AreaManager by geolocation
        listLeads.add(new Lead(
                FirstName = 'SOBCRM-1153',
                LastName = 'Test',
                PostalCode = '12345',
                CountryCode = countryCode,
                Latitude = latitude2,
                Longitude = longitude2,
                TargetCountry__c = ITALY
        ));
        insert listLeads;

        //----------------------------
        // START BATCH JOB
        //----------------------------
        Test.startTest();

        // Schedule job (onyl for code coverage)
        String jobId = System.schedule('Scheduled LeadAssignPartnerAndManagerBatch', CRON_EXPRESSION, new LeadAssignPartnerAndManagerBatch());

        // Execute it manually
        Id idBatchJob = Database.executeBatch(new LeadAssignPartnerAndManagerBatch());

        Test.stopTest();

        // Assertions
        Map<Id,Lead> mapLeads = new Map<Id,Lead>([
            SELECT
                Id,
                AssignSBC__c,
                AssignPartnerDebug__c,
                AreaManager__c,
                AssignAreaManagerDebug__c,
                WasHandledByAreaManagerAssignBatch__c,
                WasHandledByPartnerAssignBatch__c
            FROM Lead
            WHERE Id IN :listLeads
        ]);

        Lead oLeadToCheck;
        Integer index = 0;

        oLeadToCheck = mapLeads.get(listLeads.get(index++).Id);
        System.assertEquals(listAccounts.get(1).Id, oLeadToCheck.AssignSBC__c, 'Expected Partner to be found by PostalCodeArea: ' + oLeadToCheck.AssignPartnerDebug__c);
        System.assertEquals(listAreaManagers.get(0).Id, oLeadToCheck.AreaManager__c, 'Expected Area Manager to be found by PostalCodeArea: ' + oLeadToCheck.AssignAreaManagerDebug__c);
        System.assertEquals(TRUE, oLeadToCheck.WasHandledByAreaManagerAssignBatch__c);
        System.assertEquals(TRUE, oLeadToCheck.WasHandledByPartnerAssignBatch__c);

        oLeadToCheck = mapLeads.get(listLeads.get(index++).Id);
        System.assertEquals(listAccounts.get(2).Id, oLeadToCheck.AssignSBC__c, 'Expected Partner to be found by geolocation: ' + oLeadToCheck.AssignPartnerDebug__c);
        System.assertEquals(listAreaManagers.get(1).Id, oLeadToCheck.AreaManager__c, 'Expected Area Manager to be found by geolocation: ' + oLeadToCheck.AssignAreaManagerDebug__c);
        System.assertEquals(TRUE, oLeadToCheck.WasHandledByAreaManagerAssignBatch__c);
        System.assertEquals(TRUE, oLeadToCheck.WasHandledByPartnerAssignBatch__c);

        oLeadToCheck = mapLeads.get(listLeads.get(index++).Id);
        System.assertEquals(listAccounts.get(2).Id, oLeadToCheck.AssignSBC__c, 'Expected Partner to be found by geolocation: ' + oLeadToCheck.AssignPartnerDebug__c);
        System.assertEquals(listAreaManagers.get(0).Id, oLeadToCheck.AreaManager__c, 'Expected Area Manager to remain same as before due to WasHandledByAreaManagerAssignBatch__c set to TRUE and existing AreaManager: ' + oLeadToCheck.AssignAreaManagerDebug__c);
        System.assertEquals(TRUE, oLeadToCheck.WasHandledByAreaManagerAssignBatch__c);
        System.assertEquals(TRUE, oLeadToCheck.WasHandledByPartnerAssignBatch__c);

        oLeadToCheck = mapLeads.get(listLeads.get(index++).Id);
        System.assertEquals(listAccounts.get(1).Id, oLeadToCheck.AssignSBC__c, oLeadToCheck.Id + ' - Expected Partner to remain same as before due to WasHandledByPartnerAssignBatch__c set to TRUE and existing Partner: ' + oLeadToCheck.AssignPartnerDebug__c);
        System.assertEquals(listAreaManagers.get(1).Id, oLeadToCheck.AreaManager__c, 'Expected Area Manager to be found by geolocation: ' + oLeadToCheck.AssignAreaManagerDebug__c);
        System.assertEquals(TRUE, oLeadToCheck.WasHandledByAreaManagerAssignBatch__c);
        System.assertEquals(TRUE, oLeadToCheck.WasHandledByPartnerAssignBatch__c);

        oLeadToCheck = mapLeads.get(listLeads.get(index++).Id);
        System.assertEquals(NULL, oLeadToCheck.AssignSBC__c);
        System.assertEquals(TRUE, oLeadToCheck.WasHandledByAreaManagerAssignBatch__c);
        System.assertEquals(TRUE, oLeadToCheck.WasHandledByPartnerAssignBatch__c);
    }

    /**
     * Tests OpportunitySBCResubmissionStatusBatch
     *
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     * @since 2016-06-15
     * @see https://interaktiv.jira.com/browse/SOBCRM-333
     */
    @isTest static void testOpportunitySBCResubmissionStatusBatch() {

        String CRON_EXPRESSION = '0 0 0 15 3 ? 2022';

        List<Opportunity> opportunities = new List<Opportunity>();
        opportunities.add(new Opportunity(
            Name                = 'Opportunity 1',
            SBCStatus__c        = 'resubmission',
            StageName           = 'Open',
            ResubmissionDate__c = Date.today(),
            CloseDate           = Date.today()
        ));
        opportunities.add(new Opportunity(
            Name                = 'Opportunity 2',
            SBCStatus__c        = 'resubmission',
            StageName           = 'Open',
            ResubmissionDate__c = Date.today().addDays(-1),
            CloseDate           = Date.today()
        ));
        opportunities.add(new Opportunity(
            Name                = 'Opportunity 3',
            SBCStatus__c        = 'resubmission',
            StageName           = 'Open',
            ResubmissionDate__c = Date.today().addDays(1),
            CloseDate           = Date.today()
        ));
        opportunities.add(new Opportunity(
            Name                = 'Opportunity 4',
            SBCStatus__c        = 'open',
            StageName           = 'Open',
            ResubmissionDate__c = Date.today().addDays(1),
            CloseDate           = Date.today()
        ));
        insert opportunities;

        Test.startTest();

        // Schedule job (onyl for code coverage)
        String jobId = System.schedule('Scheduled OpportunitySBCResubmissionStatusBatch', CRON_EXPRESSION, new OpportunitySBCResubmissionStatusBatch());

        // Execute it manually
        Id batchJobId = Database.executeBatch(new OpportunitySBCResubmissionStatusBatch());

        Test.stopTest();

        Map<Id,Opportunity> opportunitiesToCheck = new Map<Id,Opportunity>([SELECT Id, SBCStatus__c, ResubmissionDate__c FROM Opportunity]);

        Integer i = -1;
        Opportunity opportunityToCheck;

        i++;
        opportunityToCheck = opportunitiesToCheck.get(opportunities.get(i).Id);
        System.assertEquals('open', opportunityToCheck.SBCStatus__c, 'Expect #' + (i + 1) + ' Opportunity\'s SBCStatus__c to be "Open"');
        System.assertEquals(NULL, opportunityToCheck.ResubmissionDate__c, 'Expect #' + (i + 1) + ' Opportunity\'s ResubmissionDate__c to be NULL');
        i++;
        opportunityToCheck = opportunitiesToCheck.get(opportunities.get(i).Id);
        System.assertEquals('open', opportunityToCheck.SBCStatus__c, 'Expect #' + (i + 1) + ' Opportunity\'s SBCStatus__c to be "Open"');
        System.assertEquals(NULL, opportunityToCheck.ResubmissionDate__c, 'Expect #' + (i + 1) + ' Opportunity\'s ResubmissionDate__c to be NULL');
        i++;
        opportunityToCheck = opportunitiesToCheck.get(opportunities.get(i).Id);
        System.assertEquals(opportunities.get(i).SBCStatus__c, opportunityToCheck.SBCStatus__c, 'Expect #' + (i + 1) + ' Opportunity\'s SBCStatus__c to be "' + opportunities.get(i).SBCStatus__c + '"');
        System.assertNotEquals(NULL, opportunityToCheck.ResubmissionDate__c, 'Expect #' + (i + 1) + ' Opportunity\'s ResubmissionDate__c not to be NULL');
        i++;
        opportunityToCheck = opportunitiesToCheck.get(opportunities.get(i).Id);
        System.assertEquals(opportunities.get(i).SBCStatus__c, opportunityToCheck.SBCStatus__c, 'Expect #' + (i + 1) + ' Opportunity\'s SBCStatus__c to be "' + opportunities.get(i).SBCStatus__c + '"');
        System.assertNotEquals(NULL, opportunityToCheck.ResubmissionDate__c, 'Expect #' + (i + 1) + ' Opportunity\'s ResubmissionDate__c not to be NULL');
    }

    /**
     * Tests LeadStatusLongTermToOpenBatch
     *
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     * @since 2016-06-14
     * @see https://interaktiv.jira.com/browse/SOBCRM-343
     *
     * Changelog:
     *
     * v1.1.0   2018-12-11  Dino Ursic                  - Added salesUser as Lead Owner and salesUser's Manager as future Lead Owner
     *                                                    after Batch processing
     *                                                  - Modified assertions to loop through each Lead and make assertions based on
     *                                                    logical rather than order-based assumptions
     * v1.2.0   2018-12-11  Marko Schmalenbach          Allow partial update and raise an consolidated error Case for all failures (SOBCRM-1311)
     */
    @isTest static void testLeadStatusLongTermToOpenBatch() {

        final String DEBUG_HERE = DEBUG_HEADER + 'testLeadStatusLongTermToOpenBatch() - ';

        // SOBCRM-1065 - Manager User required to test Lead reassignment
        User oManagerUser = new User(
            Username          = 'testmanager@sonnenbatterie.de.tests',
            FirstName         = 'Tester',
            LastName          = 'Testowski',
            Email             = 'testmanager@sonnenbatterie.de.tests',
            Alias             = 'ttestow',
            TimeZoneSidKey    = 'GMT',
            LocaleSidKey      = 'de_DE',
            EmailEncodingKey  = 'UTF-8',
            ProfileId         = UserInfo.getProfileId(),
            LanguageLocaleKey = 'de'
        );
        insert oManagerUser;

        User oSalesUser = new User(
            Username          = 'testmsalesrep@sonnenbatterie.de.tests',
            FirstName         = 'Tester',
            LastName          = 'Testowski',
            Email             = 'testsalesrep@sonnenbatterie.de.tests',
            Alias             = 'ttestow',
            TimeZoneSidKey    = 'GMT',
            LocaleSidKey      = 'de_DE',
            EmailEncodingKey  = 'UTF-8',
            ProfileId         =  UserInfo.getProfileId(),
            LanguageLocaleKey = 'de',
            ManagerId         = oManagerUser.Id,
            IsActive          = false
        );
        insert oSalesUser;

        // To avoid MIXED_DML_OPERATION, DML operation on setup object is not permitted
        // (see https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_dml_non_mix_sobjects_test_methods.htm)
        Group oQueueGroup;

        System.runAs(new User(Id = UserInfo.getUserId())) {

            // Create new Queue Group
            oQueueGroup = new Group(
                Name = 'Funky Bunch',
                DeveloperName = 'FunkyBunch',
                Type = 'Queue'
            );
            insert oQueueGroup;

            // Map group to Lead
            QueueSobject mappingObject = new QueueSobject(
                QueueId = oQueueGroup.Id,
                SobjectType = 'Lead'
            );
            insert mappingObject;
        }

        String CRON_EXPRESSION = '0 0 0 15 3 ? 2022';

        List<Lead> listLeads = new List<Lead>{
            new Lead(
                FirstName          = 'Duffy',
                LastName           = 'Duck',
                Status             = 'Long Term',
                ReminderDate__c    = Date.today(),
                Type__c            = 'Other',
                LeadSource         = 'Other',
                ProductInterest__c = 'eco',
                Description2__c    = 'Blabla',
                OwnerId            = oSalesUser.Id
            ),
            new Lead(
                FirstName          = 'Donald',
                LastName           = 'Duck',
                Status             = 'Long Term',
                ReminderDate__c    =  Date.today().addDays(-1),
                Type__c            = 'Other',
                LeadSource         = 'Other',
                ProductInterest__c = 'eco',
                Description2__c    = 'Blabla',
                OwnerId            = oSalesUser.Id
            ),
            new Lead(
                FirstName          = 'Mickey',
                LastName           = 'Mouse',
                Status             = 'Long Term',
                ReminderDate__c    =  Date.today().addDays(1),
                Type__c            = 'Other',
                LeadSource         = 'Other',
                ProductInterest__c = 'eco',
                Description2__c    = 'Blabla',
                OwnerId            = oSalesUser.Id
            ),
            new Lead(
                FirstName          = 'Mini',
                LastName           = 'Mouse',
                Status             = 'Open',
                ReminderDate__c    =  Date.today(),
                Type__c            = 'Other',
                LeadSource         = 'Other',
                ProductInterest__c = 'eco',
                Description2__c    = 'Blabla',
                OwnerId            = oSalesUser.Id
            ),
            new Lead(
                FirstName          = 'Queue',
                LastName           = 'Mouse',
                Status             = 'Long Term',
                ReminderDate__c    =  Date.today().addDays(-1),
                Type__c            = 'Other',
                LeadSource         = 'Other',
                ProductInterest__c = 'eco',
                Description2__c    = 'Blabla',
                OwnerId            = oQueueGroup.Id
            ),
            new Lead(
                LastName           = LeadStatusLongTermToOpenBatch.UNIT_TEST_DML_ERROR_LEAD_NAME,
                Status             = 'Long Term',
                ReminderDate__c    =  Date.today().addDays(-10),
                Type__c            = 'Other',
                LeadSource         = 'Other',
                ProductInterest__c = 'eco',
                Description2__c    = 'Blabla',
                OwnerId            = oSalesUser.Id
            )
        };

        insert listLeads;

        Test.startTest();

        // Schedule job (only for code coverage)
        //System.schedule('Scheduled LeadStatusLongTermToOpenBatch', CRON_EXPRESSION, new LeadStatusLongTermToOpenBatch());

        // Execute it manually
        System.debug(DEBUG_HERE + '----------------------- START -----------------------');
        Database.executeBatch(new LeadStatusLongTermToOpenBatch());

        Test.stopTest();

        Map<Id, Lead> leadsToCheck = new Map<Id,Lead>([
            SELECT Id, Status, ReminderDate__c, OwnerId
            FROM Lead
            WHERE Id IN :listLeads
        ]);

        // Assertions
        System.debug(DEBUG_HERE + '----------------------- ASSERTIONS -----------------------');

        for (Lead oLead : listLeads) {

            // If Lead's ReminderDate has passed (ie. older than today), the lead's status should be set to Open
            if (oLead.ReminderDate__c <= Date.today() && oLead.Status == 'Long Term') {

                System.debug(DEBUG_HERE + 'Check ' + oLead);

                if (oLead.LastName == LeadStatusLongTermToOpenBatch.UNIT_TEST_DML_ERROR_LEAD_NAME) {

                    System.assertEquals(oLead.Status, leadsToCheck.get(oLead.Id).Status, 'Expect unchanged Lead Status due to DML error');

                    List<Case> listCases = [SELECT Id, Subject, Description FROM Case WHERE Lead__c = :oLead.Id];
                    System.assertEquals(1, listCases.size(), 'Expected an error case for the failing Lead');

                    System.debug(DEBUG_HERE + 'Case: ' + listCases.get(0));

                    continue;
                }

                System.assertEquals('Open', leadsToCheck.get(oLead.Id).Status, 'Expect Lead with ReminderDate <= TODAY (' + leadsToCheck.get(oLead.Id).ReminderDate__c + ') Status to be "Open"');

                if (oLead.OwnerId == oQueueGroup.Id) {
                    System.assertEquals(oQueueGroup.Id, leadsToCheck.get(oLead.Id).OwnerId, 'Expect Lead with ReminderDate <= TODAY to have the same Queue Owner as before');
                }
                else {
                    System.assertEquals(oManagerUser.Id, leadsToCheck.get(oLead.Id).OwnerId, 'Expect Lead with ReminderDate <= TODAY to have new Owner');
                }
            }

            // Leads with ReminderDate higher than TODAY or with Status different than 'Long Term' should not be processed by the batch
            if (oLead.ReminderDate__c > Date.today() || oLead.Status != 'Long Term') {
                System.assertEquals(oLead.Status, leadsToCheck.get(oLead.Id).Status, 'Expect unchanged Status for the Lead with ReminderDate ' + oLead.ReminderDate__c + ' and Status "' + oLead.Status + '"');
                System.assertEquals(oLead.OwnerId, leadsToCheck.get(oLead.Id).OwnerId, 'Expect unchanged Owner for the Lead with ReminderDate ' + oLead.ReminderDate__c + ' and Status "' + oLead.Status + '"');
            }
        }

        System.debug(DEBUG_HERE + '----------------------- STOP -----------------------');
    }
}