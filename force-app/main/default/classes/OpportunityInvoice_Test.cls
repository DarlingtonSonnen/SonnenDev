@isTest
public class OpportunityInvoice_Test {

    static testMethod void testCreateInvoice() {
        
        Account a = new Account( Name = 'Name' );
        insert a;
        
        Contact c = new Contact( LastName = 'LastName', AccountId = a.Id );
        insert c;
 
        invt__Invoice_Item__c ii = new invt__Invoice_Item__c();
        insert ii;
        
        Product2 p = new Product2( Name = 'Product', Invoice_Item__c = ii.Id );
        insert p;
        
        PriceBookEntry pbe = new PriceBookEntry( Product2Id = p.Id, PriceBook2Id = Test.getStandardPricebookId(), UnitPrice = 1, isActive = true);
        insert pbe;
        
        Opportunity o = new Opportunity();
        o.Name = 'Test Opp';
        o.AccountId = a.Id;
        o.PrimaryContact__c = c.Id;
        o.Financing__c = 'Upfront';
        o.CloseDate = System.Today();
        o.StageName = 'Requested';
        o.Create_Invoice__c = 'Yes';
        o.Pricebook2Id = Test.getStandardPricebookId();
        insert o;
        
        OpportunityLineItem oli = new OpportunityLineItem( OpportunityId = o.Id, Quantity = 1, PricebookEntryId = pbe.Id, TotalPrice = 1 );
        insert oli;
        
        List<Opportunity> oList = new List<Opportunity>();
        oList.add(o);
        
        OpportunityInvoice.createInvoice(oList);
            
        
    }
    
}