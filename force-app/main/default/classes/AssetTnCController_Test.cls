/**
 * Created by b.jarmolinski on 19/04/2018.
 */
@isTest
public class AssetTnCController_Test {

    static testMethod void testMethod1() {
        Account acc = new Account(Name='newAccount');
        insert acc;

        Asset a = new Asset(Name = '#12345 Bartosz LastName', SerialNumber = '12345', INClientFirstName__c = 'Bartosz', INClientLastName__c = 'LastName', INClientPhoneNumber__c = '2354345', INClientStreet__c = 'Zossener',
                    INClientAdditionToAddress__c='56', INClientZIPCode__c='10245', INClientSalutation__c='Mr.', INClientCity__c='Berlin', AccountId = acc.Id, Country__c = 'DE');
        insert a;

        List<TermsAndConditions__c> tncList = new List<TermsAndConditions__c>();

        TermsAndConditions__c tnc1 = new TermsAndConditions__c(Name='privacy', Type__c='Privacy Policy', Language__c = 'DE', Country__c = 'DE', Current__c = true);
        TermsAndConditions__c tnc2 = new TermsAndConditions__c(Name='TnC', Type__c='General TnC', Language__c = 'DE', Country__c = 'DE', Current__c = true);
        TermsAndConditions__c tnc3 = new TermsAndConditions__c(Name='warranty', Type__c='Warranty Conditions', Language__c = 'DE', Country__c = 'DE', Current__c = true);
        TermsAndConditions__c tnc4 = new TermsAndConditions__c(Name='warranty', Type__c='Manufacture Guarantee', Language__c = 'DE', Country__c = 'DE', Current__c = true);

        tncList.add(tnc1);
        tncList.add(tnc2);
        tncList.add(tnc3);
        tncList.add(tnc4);

        insert tncList;
        System.debug('tncs: '+[SELECT Id FROM TermsAndConditions__c]);

        List<Attachment> amList = new List<Attachment>();
        Attachment am1 = new Attachment();
        am1.Name = 'Privacy policy';
        am1.parentId = tnc1.Id;
        Blob bodyBlob1 = Blob.valueOf('bdy of attachment 1');
        am1.body = bodyBlob1;
        amList.add(am1);

        Attachment am2 = new Attachment();
        am2.Name = 'General terms and conditions';
        am2.parentId = tnc2.Id;
        Blob bodyBlob2 = Blob.valueOf('bdy of attachment 2');
        am2.body = bodyBlob2;
        amList.add(am2);

        Attachment am3 = new Attachment();
        am3.Name = 'Warranty terms';
        am3.parentId = tnc3.Id;
        Blob bodyBlob3 = Blob.valueOf('bdy of attachment 3');
        am3.body = bodyBlob3;
        amList.add(am3);

        Attachment am4 = new Attachment();
        am4.Name = 'Manufacture Guarantee';
        am4.parentId = tnc4.Id;
        Blob bodyBlob4 = Blob.valueOf('bdy of attachment 4');
        am4.body = bodyBlob4;
        amList.add(am4);

        insert amList;
        System.debug('attachments: '+[SELECT Id FROM Attachment]);

        PageReference pageRef = new PageReference('apex/Asset5TnC?id='+a.Id+'&language=de');
        Test.setCurrentPage(pageRef);

        AssetTnCController5 controller = new AssetTnCController5();

        List<selectOption> options = controller.getItems();
        System.assertEquals(2, options.size());

        // simulate sending different data
        AssetTnCController5.AssetWrapper wrap = new AssetTnCController5.AssetWrapper();
        controller.AssetWrapper.salutation = 'Mr.';
        controller.AssetWrapper.firstName = 'newName';
        controller.AssetWrapper.lastName = 'ChangedLastName';
        controller.AssetWrapper.phone = '111222';
        controller.AssetWrapper.street = 'Am Riedbach';
        controller.AssetWrapper.streetNumber = '1';
        controller.AssetWrapper.postCode = '87000';
        controller.AssetWrapper.city = 'Wildpoldsried';

        controller.accepted1 = true;
        controller.accepted2 = true;
        controller.accepted3 = true;
        controller.accepted4 = true;
        controller.accepted5 = true;
        controller.accepted6 = true;

        // call confirm
        Test.startTest();
        controller.confirm();
        Test.stopTest();

        // assert that DTO has been created
        System.assertEquals(1, [SELECT Id FROM DataTransferObject__c].size());

        // assert that TnCsAssets have been created
        System.assertEquals(2, [SELECT Id FROM TnCsAcceptance__c].size());
        System.assert([SELECT DateTimeAccepted__c FROM TnCsAcceptance__c LIMIT 1].DateTimeAccepted__c != null);

        // assert that the data has been updated
        System.assertEquals('newName', [SELECT INClientFirstName__c FROM Asset WHERE Id =:a.Id].INClientFirstName__c);

        controller.confirm();
    }

}