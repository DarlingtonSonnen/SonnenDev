@isTest
private class TermsAndConditionsTrigger_test {
    
    @isTest static void test_method_one() {

        List<String> typeOptions = new List<String>{'General TnC', 'Privacy policy'};

        List<TermsAndConditions__c> tcl = new List<TermsAndConditions__c>();

        TermsAndConditions__c tc = new TermsAndConditions__c(
                TnCsText__c = 'text goes here',
                Type__c = typeOptions[0],
                Country__c = 'DE',
                Language__c = 'DE',
                Current__c = true
        );
        tcl.add(tc);

        TermsAndConditions__c td = new TermsAndConditions__c(
                TnCsText__c = 'text goes here',
                Type__c = typeOptions[1],
                Country__c = 'DE',
                Language__c = 'DE',
                Current__c = true
        );
        tcl.add(td);
        insert tcl;

        System.assertEquals(1, [SELECT Version__c FROM TermsAndConditions__c WHERE Id =:tc.Id].Version__c);
        System.assertEquals(1, [SELECT Version__c FROM TermsAndConditions__c WHERE Id =:td.Id].Version__c);
        
        // insert of of new t&c with current == true
        TermsAndConditions__c te = new TermsAndConditions__c( 
                ExpirationDate__c = Date.today(),
                TnCsText__c = 'text goes here - new terms',
                Type__c = typeOptions[0],
                Current__c = true,
                Language__c = 'DE',
                Country__c = 'DE'
        );
        insert te;
        // assert that the previous version of the te has been set to not-current (tc)
        System.assertEquals(false, [SELECT Current__c FROM TermsAndConditions__c WHERE Id = :tc.Id ].Current__c);

        // check that the previous version number stayed unaffected and is still version 1
        System.assertEquals(1, [SELECT Version__c FROM TermsAndConditions__c WHERE Id =:tc.Id].Version__c);

        // assert that version number of the new record has been incremented
        System.assertEquals(2,[SELECT Version__c FROM TermsAndConditions__c WHERE Id =:te.Id].Version__c);

        // make sure the other terms record (td) stayed unaffected and is still current
        System.assertEquals(true, [SELECT Current__c FROM TermsAndConditions__c WHERE Id = :td.Id].Current__c);


        // insert new version of te without marking it current, make sure the te is still current
        TermsAndConditions__c tf = new TermsAndConditions__c(
                TnCsText__c = 'another version but not marked as current',
                Type__c = typeOptions[0],
                Country__c = 'DE',
                Language__c = 'DE',
                Current__c = false
        );

        insert tf;

        // assert that the previous version is still marked as current
        System.assertEquals(true, [SELECT Current__c FROM TermsAndConditions__c WHERE Id = :te.Id ].Current__c);
        // assert version has been added
        System.assertEquals(3, [SELECT Version__c FROM TermsAndConditions__c WHERE Id =:tf.Id].Version__c);

        // set tf as current, assert that te current has been set to false
        tf.Current__c = true;
        update tf;

        System.assertEquals(true, [SELECT Current__c FROM TermsAndConditions__c WHERE Id = :tf.Id ].Current__c);
        System.assertEquals(1, [SELECT Id FROM TermsAndConditions__c WHERE Current__c = true AND Country__c = 'DE' AND Language__c = 'DE' AND Type__c = :typeOptions[0]].size());
        // same assertion to make sure setting current did not affect versioning
        System.assertEquals(3, [SELECT Version__c FROM TermsAndConditions__c WHERE Id =:tf.Id].Version__c);

        // insert document with different language, make sure the tf is still current
        TermsAndConditions__c tg = new TermsAndConditions__c(
                TnCsText__c = 'document with type and country same as tf, but with different language',
                Type__c = typeOptions[0],
                Country__c = 'DE',
                Language__c = 'EN',
                Current__c = true
        );
        insert tg;
        System.assertEquals(true, [SELECT Current__c FROM TermsAndConditions__c WHERE Id = :tf.Id ].Current__c);
        System.assertEquals(1, [SELECT Version__c FROM TermsAndConditions__c WHERE Id =:tg.Id].Version__c);

        // insert document with different country and check that tf is still current
        TermsAndConditions__c th = new TermsAndConditions__c(
                TnCsText__c = 'document with type and country same as tf, but with different language',
                Type__c = typeOptions[0],
                Country__c = 'AT',
                Language__c = 'DE',
                Current__c = true
        );
        insert th;

        System.assertEquals(true, [SELECT Current__c FROM TermsAndConditions__c WHERE Id = :tf.Id ].Current__c);
    }
}