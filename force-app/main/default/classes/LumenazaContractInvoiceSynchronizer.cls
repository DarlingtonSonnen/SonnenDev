/**
 * LumenazaContractInvoiceSynchronizer
 *
 * Synchronizes Lumenaza Invoices for Contracts
 *
 * Tested by LumenazaTest.testLumenazaContractInvoiceSynchronizer()
 *
 * Changelog
 * ---------
 *
 * v1.1.0-2018-07-05 (SOBCRM-1228)
 * - Remove Stage on cases - 'Sync Lumenaza Error'
 *
 * v1.0.0 (2017-09-11)
 * - Initial version
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.0.0 (2017-09-11)
 * @see https://interaktiv.jira.com/browse/SOBCRM-705
 * @see LumenazaTest.testLumenazaContractInvoiceSynchronizer()
 */
public class LumenazaContractInvoiceSynchronizer {

    private static final String DEBUG_HEADER = 'LumenazaContractInvoiceSynchronizer.';

    public static final String RECORD_TYPE_ID_PAYMENT = DiaUtilities.getRecordTypeIdByObjectAndName('Payment__c', 'Lumenaza');

    private static final Map<String,Map<String,String>> INVOICE_TO_PAYMENT_MAPPING = new Map<String,Map<String,String>>{

        // Mapping: CSV <-> Payment__c object
        // Common mappings for both types ("summarized" and "bill"
        '_common' => new Map<String,String>{
            'customerID'                    => 'Lumenaza_CustomerId__c',
            'SEPA-Mandatsreferenznummer'    => '',
            'SEPA-Mandatsdatum'             => '',
            'Vertragsnummer'                => 'Lumenaza_ContractNo__c',
            'delivery_start'                => '',
            'delivery_end'                  => '',
            'customer_label'                => 'Lumenaza_customerLabel__c',
            'Adressatentyp'                 => 'AdressType__c',
            'company name'                  => 'Lumenaza_CompanyName__c',
            'company_contact'               => 'Lumenaza_CompanyContact__c',
            'last_name'                     => 'Lumenaza_LastName__c',
            'first_name'                    => 'Lumenaza_FirstName__c',
            'sex'                           => 'Lumenaza_Sex__c',
            'deliv_street'                  => 'Lumenaza_DelivStreet__c',
            'deliv_house_nr'                => 'Lumenaza_DelivHouseNr__c',
            'Adresszusatz'                  => '',
            'deliv_zip_code'                => 'Lumenaza_DelivZipCode__c',
            'deliv_city'                    => 'Lumenaza_DelivCity__c',
            'Zählpunkt-Nr.'                 => 'Lumenaza_MeterpointNo__c',
            'Rechnungsnummer'               => 'Lumenaza_InvoiceNo__c',
            'Rechnungsdatum'                => 'Lumenaza_InvoiceDate__c',
            'Datum Abbuchung'               => 'DebitDate__c'
        },
        // Special mapping for "summarized"
        'summarized' => new Map<String,String>{
            'Installment date'              => 'Lumenaza_InstallmentDate__c',
            'Abschlags-Summe'               => 'Amount__c',
            'Bonus-ID'                      => 'BonusIds__c' // Salesforce ID
        },
        // Special mapping for "bill"
        'bill' => new Map<String,String>{
            'Rechnungssumme'                => 'Amount__c'
        }
    };
    
    private List<Case> errorCases = new List<Case>();
    private String defaultErrorCaseDescription = '';

    private LumenazaApi lumenazaApi;

    /**
     * Constructor
     */
    public LumenazaContractInvoiceSynchronizer() {
        this.lumenazaApi = new LumenazaApi(TRUE); // Force live environment
    }

    @future(callout=true)
    public static void executeSynchronizer(String invoiceType, Integer year, Integer month) {
        LumenazaContractInvoiceSynchronizer oSynchronizer = new LumenazaContractInvoiceSynchronizer();
        oSynchronizer.synchronize(invoiceType, year, month);
    }

    public void synchronize(String invoiceType, Integer year, Integer month) {
        this.synchronize(invoiceType, year, month, 0);
    }

    /**
     * Synchronize Lumenaza invoices with local Payments
     */
    public void synchronize(String invoiceType, Integer year, Integer month, Integer maxLogMultiple) {

        String DEBUG_HERE = DEBUG_HEADER + 'synchronize() - ';
        Boolean bCreateCases = TRUE;

        String sSource = 'LumenazaContractInvoiceSynchronizer (type: ' + invoiceType + ', year: ' + year + ', month: ' + month + ')';

        // Check creation of cases
        try {
            LumenazaSettings__c oLumenazaSettings = LumenazaSettings__c.getValues('api');
            bCreateCases = !oLumenazaSettings.InvoiceSynchronizerDontCreateCases__c;
        }
        catch (Exception e) {}

        if (invoiceType != 'bill' && invoiceType != 'summarized') {
            throw new LumenazaContractInvoiceSynchronizerException('Invalid invoice type given, must be either "bill" or "summarized"');
        }

        if (RECORD_TYPE_ID_PAYMENT == NULL) {
            throw new LumenazaContractInvoiceSynchronizerException('Record Type for Payment__c is not set');
        }

        this.defaultErrorCaseDescription = 'Import of Lumenaza payments of type "' + invoiceType + '" for ' + year + '-' + month;

        if (maxLogMultiple > 0) {
            System.debug(DEBUG_HERE + 'ATTENTION: Debug log lists are partially limited to ' + maxLogMultiple + ' entries');
        }

        Map<String,Payment__c> mapInvoicesPayments = this.fetchInvoicesAsPaymentObjects(invoiceType, year, month, maxLogMultiple, bCreateCases);

        if (mapInvoicesPayments == NULL || mapInvoicesPayments.isEmpty()) {
            System.debug(DEBUG_HERE + 'No Payment__c objects to process');
            return;
        }

        this.defaultErrorCaseDescription += '\n\nImported as Payment__c objects extract:\n';
        String sInvoicePayments = String.valueOf(mapInvoicesPayments.values());
        this.defaultErrorCaseDescription += sInvoicePayments.length() > 5000 ? sInvoicePayments.substring(0,5000) : sInvoicePayments;

        System.debug(DEBUG_HERE + 'Handle ' + mapInvoicesPayments.size()  + ' Payment__c objects from import');

        // Get invoice numbers to find existing Payment__c objects
        // by Lumenaza_InvoiceNo__c
        Set<String> lsetInvoiceNumbers = mapInvoicesPayments.keySet();

        Map<String,String> mapMapping = this.getInvoiceMapping(invoiceType);
        Set<String> lsetQueryFields = new Set<String>();

        for (String sField : mapMapping.values()) {
            if (!this.isEmptyString(sField)) {
                lsetQueryFields.add(sField);
            }
        }

        // Mandatory to relate invoices to contracts later
        lsetQueryFields.add('Lumenaza_ContractNo__c');

        List<Payment__c> listExistingPayments = Database.query(
            'SELECT Id,' + String.join(new List<String>(lsetQueryFields), ',') + ',(SELECT Bonus__c, Source__c FROM BonusToPayments__r) ' +
            'FROM Payment__c ' +
            'WHERE Lumenaza_InvoiceNo__c IN :lsetInvoiceNumbers');

        Map<String,Payment__c> mapExistingInvoiceNoToPayment = new Map<String,Payment__c>();

        System.debug(DEBUG_HERE + 'Found ' + listExistingPayments.size() + ' existing Payment__c object(s) as update candidates');

        // Sort InvoiceNo to Payment__c
        if (!listExistingPayments.isEmpty()) {

            for (Payment__c oPayment : listExistingPayments) {
                mapExistingInvoiceNoToPayment.put(oPayment.Lumenaza_InvoiceNo__c, oPayment);
            }
        }

        Map<String,List<Payment__c>> mapPaymentsToInsertByContractNumber = new Map<String,List<Payment__c>>();

        List<Payment__c> listPaymentsToInsert = new List<Payment__c>();
        List<Payment__c> listPaymentsToUpdate = new List<Payment__c>();

        Integer iDebugCountUpdate = 0;
        Integer iDebugCountInsert = 0;
        Integer iDebugCountInsertError = 0;
        
        // For error cases
        List<String> listImportPaymentsWithMissingContractNo        = new List<String>();
        List<String> listImportPaymentsWhichContractCouldNotBeFound = new List<String>();

        Set<Id> lsetBonusIds = new Set<Id>();

        // Check wether incoming already exists
        for (Payment__c oPaymentFromImport : mapInvoicesPayments.values()) {

            // Collect Bonus IDs
            if (!this.isEmptyString(oPaymentFromImport.BonusIds__c)) {
                lsetBonusIds.addAll(this.getBonusIdsFromString(oPaymentFromImport.BonusIds__c));
            }

            // UPDATE
            if (mapExistingInvoiceNoToPayment.containsKey(oPaymentFromImport.Lumenaza_InvoiceNo__c)) {

                iDebugCountUpdate++;

                Payment__c oPaymentExisting = mapExistingInvoiceNoToPayment.get(oPaymentFromImport.Lumenaza_InvoiceNo__c);
                Payment__c oPaymentExistingClone = oPaymentExisting.clone(TRUE, TRUE);

                if (maxLogMultiple == 0 || iDebugCountUpdate <= maxLogMultiple) {
                    System.debug(DEBUG_HERE + 'UPDATE: Payment__c ' + oPaymentExisting.Id + ' found in import by Lumenaza_InvoiceNo__c "' + oPaymentFromImport.Lumenaza_InvoiceNo__c + '"');
                }

                Boolean bHasDifference = FALSE;

                Map<String,String> mapExistingPaymentValues = DiaUtilities.getObjectValuesAsMap(oPaymentExisting);
                Map<String,String> mapImportPaymentValues   = DiaUtilities.getObjectValuesAsMap(oPaymentFromImport);

                for (String sField : lsetQueryFields) {

                    String sValueImport   = String.valueOf(mapImportPaymentValues.get(sField) == NULL ? '' : mapImportPaymentValues.get(sField).trim());
                    String sValueExisting = String.valueOf(mapExistingPaymentValues.get(sField) == NULL ? '' : mapExistingPaymentValues.get(sField).trim());
                    Boolean bDiffer = (sValueImport != sValueExisting);

                    // Force value from import
                    if (bDiffer) {
                        bHasDifference = TRUE;
                        mapExistingPaymentValues.put(sField, sValueImport);
                        System.debug(DEBUG_HERE + 'UPDATE:    * Field "' + sField + '" differs, import: ' + sValueImport + ' <-> existing: ' + sValueExisting);
                    }
                }

                // Register existing Payment for update
                // if any difference was found
                if (bHasDifference) {

                    // Update existing Payment__c
                    Payment__c oPaymentWithUpdatedValues = (Payment__c)JSON.deserialize(JSON.serialize(mapExistingPaymentValues), Type.forName('Payment__c'));

                    for (String sField : mapExistingPaymentValues.keySet()) {
                        oPaymentExisting.put(sField, oPaymentWithUpdatedValues.get(sField));
                    }

                    listPaymentsToUpdate.add(oPaymentExisting);
                }
            }
            // INSERT
            else {

                iDebugCountInsert++;

                String lumenazaContractNoFromImport = oPaymentFromImport.Lumenaza_ContractNo__c;

                if (maxLogMultiple == 0 || iDebugCountInsert <= maxLogMultiple) {
                    System.debug(DEBUG_HERE + 'INSERT: New Payment__c with Lumenaza_ContractNo__c "' + lumenazaContractNoFromImport + '"');
                }

                if (this.isEmptyString(lumenazaContractNoFromImport)) {

                    iDebugCountInsertError++;

                    if (maxLogMultiple == 0 || iDebugCountInsertError <= maxLogMultiple) {
                        System.debug(DEBUG_HERE + 'INSERT: Error: Payment__c has no Lumenaza_ContractNo__c: ' + oPaymentFromImport);
                    }

                    listImportPaymentsWithMissingContractNo.add(String.valueOf(oPaymentFromImport));
                }
                else {

                    // Sort new Payment__c objects to LumenazaContractNo
                    if (!mapPaymentsToInsertByContractNumber.containsKey(lumenazaContractNoFromImport)) {
                        mapPaymentsToInsertByContractNumber.put(lumenazaContractNoFromImport, new List<Payment__c>());
                    }

                    mapPaymentsToInsertByContractNumber.get(lumenazaContractNoFromImport).add(oPaymentFromImport);
                }
            }
        }

        // Get Bonuses
        Map<Id,Bonus__c> mapBonusesByIds = new Map<Id,Bonus__c>();

        if (!lsetBonusIds.isEmpty()) {
            try {
                mapBonusesByIds = new Map<Id,Bonus__c>([SELECT Id, Name FROM Bonus__c WHERE Id IN :lsetBonusIds]);
            }
            catch (Exception e) {
                this.addErrorCase('Error at fetching bonuses', e.getMessage() + '\n\n' + e.getStackTraceString());
                if (bCreateCases) insert this.errorCases;
                return;
            }
        }

        // INSERT
        // Relate new Payment__c objects to their Contract by contract number
        if (!mapPaymentsToInsertByContractNumber.isEmpty()) {

            System.debug(DEBUG_HERE + 'INSERT: New Payment__c objects to Lumenaza contract ID: ' + mapPaymentsToInsertByContractNumber);

            // Regard limits?
            List<Contract> listContracts = new List<Contract>([
                SELECT Id, LumenazaContractId__c
                FROM Contract
                WHERE LumenazaContractId__c IN :mapPaymentsToInsertByContractNumber.keySet()
            ]);

            if (listContracts.isEmpty()) {

                // If updates are present
                if (!listPaymentsToUpdate.isEmpty()) {

                    String sMessage = 'None of these new invoices could be matched to an existing contract: ' + String.join(new List<String>(mapPaymentsToInsertByContractNumber.keySet()), ', ');

                    System.debug(DEBUG_HERE + 'INSERT Error: ' + sMessage);
                    this.addErrorCase(
                        'New Contracts not found for imports',
                        sMessage
                    );
                }
                // If only inserts
                else {
                    System.debug(DEBUG_HERE + 'INSERT: Error, no existing contract found by Lumenaza_ContractNo__c for any NEW Payment__c objects to import');
                    this.addErrorCase(
                        'Contracts not found for imports',
                        'None of the NEW imported invoices to insert could be matched to any existing contract'
                    );
                }
            }
            else {

                // Map LumenazaContractId -> Contract ID
                Map<String,Id> mapLumenazaContractIdToContractId = new Map<String,Id>();
                for (Contract oContract : listContracts) {
                    mapLumenazaContractIdToContractId.put(oContract.LumenazaContractId__c, oContract.Id);
                }

                Integer iDebugCountRelate = 0;
                Integer iDebugCountContractNotFound = 0;

                // Check wether each new invoice was found
                for (String sContractNoFromImport : mapPaymentsToInsertByContractNumber.keySet()) {

                    Id idOfContractToRelatePaymentTo = mapLumenazaContractIdToContractId.get(sContractNoFromImport);

                    // If contract no from import could not be found in existing contracts then open a case
                    if (idOfContractToRelatePaymentTo == NULL) {
                        
                        iDebugCountContractNotFound++;

                        if (maxLogMultiple == 0 || iDebugCountContractNotFound <= maxLogMultiple) {
                            System.debug(DEBUG_HERE + 'INSERT: Contract No "' + sContractNoFromImport + '" was not found in existing contracts - open a case');
                        }

                        listImportPaymentsWhichContractCouldNotBeFound.add(sContractNoFromImport);
                    }
                    // Else relate all Payment__c objects with Lumenaza_ContractNo__c to
                    // their corresponding contract
                    else {

                        iDebugCountRelate++;

                        List<Payment__c> listPaymentsToRelate = mapPaymentsToInsertByContractNumber.get(sContractNoFromImport);

                        if (maxLogMultiple == 0 || iDebugCountRelate <= maxLogMultiple) {
                            System.debug(DEBUG_HERE + 'INSERT: Relate ' + listPaymentsToRelate.size() + ' Payment__c object(s) to contract with LumenazaContractId ' + sContractNoFromImport + ' (ID ' + idOfContractToRelatePaymentTo + ')');
                        }

                        for (Payment__c oPayment : listPaymentsToRelate) {
                            oPayment.Contract__c     = idOfContractToRelatePaymentTo;
                            oPayment.ImportSource__c = sSource;
                            oPayment.Name            = 'LUMINV-' + oPayment.Lumenaza_InvoiceNo__c;
                            listPaymentsToInsert.add(oPayment);
                        }
                    }
                }
            }
        } // end !mapPaymentsToInsertByContractNumber.isEmpty()

        // BonusToPaymentLink__c
        List<BonusToPaymentLink__c> listBonusToPaymentLinkToDelete = new List<BonusToPaymentLink__c>();
        Map<String,List<BonusToPaymentLink__c>> mapLumenazaInvoiceNoToBonusToPaymentLinksToInsert = new Map<String,List<BonusToPaymentLink__c>>();
        Integer iBonusToPaymentLinksWithoutPaymentId = 0;

        if (!listPaymentsToUpdate.isEmpty() || !listPaymentsToInsert.isEmpty()) {

            System.debug(DEBUG_HERE + 'Payment__c objects to UPDATE: ' + listPaymentsToUpdate.size());
            System.debug(DEBUG_HERE + 'Payment__c objects to INSERT: ' + listPaymentsToInsert.size());

            List<Payment__c> listPaymentsToUpsert = new List<Payment__c>();
            listPaymentsToUpsert.addAll(listPaymentsToUpdate);
            listPaymentsToUpsert.addAll(listPaymentsToInsert);

            // Check bonuses and if not found raise a case
            // else create a junction BonusToPaymentLink__c object as
            // there can be multiple bonuses for one payment/invoice
            for (Payment__c oPayment : listPaymentsToUpsert) {

                System.debug(DEBUG_HERE + 'Payment to upsert "' + oPayment.Lumenaza_InvoiceNo__c + '"');

                // Check changes on existing bonuses
                List<BonusToPaymentLink__c> listBonusToPaymentLinks = oPayment.BonusToPayments__r;

                Map<Id,BonusToPaymentLink__c> mapBonusToPaymentLinksByIds = new Map<Id,BonusToPaymentLink__c>();
                Set<Id> lsetBonusIdsPayment = new Set<Id>();

                if (!listBonusToPaymentLinks.isEmpty()) {

                    System.debug(DEBUG_HERE + '    - ' + listBonusToPaymentLinks.size() + ' bonus(es) are currently linked to Payment');
                    Integer i = 1;

                    for (BonusToPaymentLink__c oBonusToPaymentLink : listBonusToPaymentLinks) {
                        System.debug(DEBUG_HERE + '        #' + (i++) + ' ' + oBonusToPaymentLink.Bonus__c);
                        mapBonusToPaymentLinksByIds.put(oBonusToPaymentLink.Bonus__c, oBonusToPaymentLink);
                    }
                }

                if (!this.isEmptyString(oPayment.BonusIds__c)) {

                    lsetBonusIdsPayment = this.getBonusIdsFromString(oPayment.BonusIds__c);
                    System.debug(DEBUG_HERE + '    - Bonus IDs from import ' + oPayment.Lumenaza_InvoiceNo__c + ': ' + lsetBonusIdsPayment.size() + ' (' + lsetBonusIdsPayment + ')');

                    if (!lsetBonusIdsPayment.isEmpty()) {

                        for (Id idBonus : lsetBonusIdsPayment) {

                            if (!mapBonusesByIds.containsKey(idBonus)) {
                                // Raise a case
                                System.debug(DEBUG_HERE + '    - Bonus ' + idBonus + ' for ' + oPayment.Lumenaza_InvoiceNo__c + ' could not be found');
                                this.addErrorCase('Bonus for import invoice not found', 'Bonus "' + idBonus + '" for ' + oPayment.Lumenaza_InvoiceNo__c + ' could not be found:\n' + oPayment);
                                lsetBonusIdsPayment.remove(idBonus);
                            }
                        }
                    }
                }

                // BonusToPaymentLinks which should exist afterwards
                System.debug(DEBUG_HERE + '    - New BonusToPaymentLink__c objects');
                Integer iNewLinks = 0;

                for (Id idBonus : lsetBonusIdsPayment) {

                    // Bonus is currently not linked to the Payment
                    if (!mapBonusToPaymentLinksByIds.containsKey(idBonus)) {
                        
                        String sInvoiceNo = oPayment.Lumenaza_InvoiceNo__c;
                        
                        // add new PaymentLink
                        if (!mapLumenazaInvoiceNoToBonusToPaymentLinksToInsert.containsKey(sInvoiceNo)) {
                            mapLumenazaInvoiceNoToBonusToPaymentLinksToInsert.put(sInvoiceNo, new List<BonusToPaymentLink__c>());
                        }

                        mapLumenazaInvoiceNoToBonusToPaymentLinksToInsert.get(sInvoiceNo).add(
                            new BonusToPaymentLink__c(
                                Bonus__c   = idBonus,
                                Payment__c = oPayment.Id != NULL ? oPayment.Id : NULL,
                                Source__c  = sSource
                            )
                        );
                        iNewLinks++;

                        System.debug(DEBUG_HERE + '        #' + iNewLinks + '  Link for Bonus ' + idBonus + ' and InvoiceNo "' + sInvoiceNo + '" -> Payment__c ' + (oPayment.Id != NULL ? '"' + oPayment.Id + '"' : '(will be defined later)'));

                        if (oPayment.Id == NULL) {
                            iBonusToPaymentLinksWithoutPaymentId++;
                        }
                    }
                }

                if (iNewLinks == 0) {
                    System.debug(DEBUG_HERE + '        - none');
                }

                // BonusToPaymentLinks to delete
                System.debug(DEBUG_HERE + '    - BonusToPaymentLink__c objects to delete');
                Integer iLinksToDelete = 0;

                for (BonusToPaymentLink__c oBonusToPaymentLink : listBonusToPaymentLinks) {
                    if (!lsetBonusIdsPayment.contains(oBonusToPaymentLink.Bonus__c)) {
                        iLinksToDelete++;
                        System.debug(DEBUG_HERE + '        #' + iLinksToDelete + ' Link for Bonus ' + oBonusToPaymentLink.Bonus__c);
                        listBonusToPaymentLinkToDelete.add(oBonusToPaymentLink);
                    }
                }

                if (iLinksToDelete == 0) {
                    System.debug(DEBUG_HERE + '        - none');
                }
            }

            // DML operations
            while (TRUE) {

                try {
                    System.debug(DEBUG_HERE + 'Upsert ' + listPaymentsToUpsert.size() + ' Payment__c object(s)');
                    upsert listPaymentsToUpsert;
                }
                catch (Exception e) {
                    System.debug(DEBUG_HERE + 'DML error: ' + e.getMessage() + ' (' + e.getStackTraceString() + ')');
                    this.addErrorCase('Imported payments could not be saved', e.getMessage() + '\n\n' + e.getStackTraceString());
                    break;
                }

                // Set Payment__c ID for BonusToPaymentLink without one
                Integer iBonusToPaymentLinksWithSetPaymentid = 0;

                for (Payment__c oPayment : listPaymentsToUpsert) {

                    String sInvoiceNo = oPayment.Lumenaza_InvoiceNo__c;

                    if (mapLumenazaInvoiceNoToBonusToPaymentLinksToInsert.containsKey(sInvoiceNo)) {
                        for (BonusToPaymentLink__c oBonusToPaymentLink : mapLumenazaInvoiceNoToBonusToPaymentLinksToInsert.get(sInvoiceNo)) {
                            if (oBonusToPaymentLink.Payment__c == NULL) {
                                iBonusToPaymentLinksWithSetPaymentid++;
                                oBonusToPaymentLink.Payment__c = oPayment.Id;
                            }
                        }
                    }
                }

                // INSERT BonusToPaymentLink__c objects
                if (!mapLumenazaInvoiceNoToBonusToPaymentLinksToInsert.isEmpty()) {

                    List<BonusToPaymentLink__c> listBonusToPaymentLinksToInsert = new List<BonusToPaymentLink__c>();

                    System.assertEquals(iBonusToPaymentLinksWithoutPaymentId, iBonusToPaymentLinksWithSetPaymentid, 'Expected set Payment IDs for all BonusToPaymentLinks__c objects without Payment ID');

                    for (List<BonusToPaymentLink__c> listBonusToPaymentLinks : mapLumenazaInvoiceNoToBonusToPaymentLinksToInsert.values()) {
                        listBonusToPaymentLinksToInsert.addAll(listBonusToPaymentLinks);
                    }

                    try {
                        System.debug(DEBUG_HERE + 'Insert ' + listBonusToPaymentLinksToInsert.size() + ' BonusToPaymentLink__c object(s)');
                        insert listBonusToPaymentLinksToInsert;
                    }
                    catch (Exception e) {
                        System.debug(DEBUG_HERE + 'DML error: ' + e.getMessage() + ' (' + e.getStackTraceString() + ')');
                        this.addErrorCase('Creation of BonusToPaymentLinks failed', e.getMessage() + '\n\n' + e.getStackTraceString());
                        break;
                    }
                }

                // DELETE BonusToPaymentLink__c objects
                if (!listBonusToPaymentLinkToDelete.isEmpty()) {
                    try {
                        System.debug(DEBUG_HERE + 'Delete ' + listBonusToPaymentLinkToDelete.size() + ' BonusToPaymentLink__c object(s)');
                        delete listBonusToPaymentLinkToDelete;
                    }
                    catch (Exception e) {
                        System.debug(DEBUG_HERE + 'DML error: ' + e.getMessage() + ' (' + e.getStackTraceString() + ')');
                        this.addErrorCase('Deletion of BonusToPaymentLinks failed', e.getMessage() + '\n\n' + e.getStackTraceString());
                        break;
                    }
                }
                
                break;
            }
        }

        if (!listImportPaymentsWithMissingContractNo.isEmpty()) {
            String sErrorDescription = 'The following import invoices have no contract no.:\n' +
                '• ' + String.join(listImportPaymentsWithMissingContractNo, '\n• ');
            this.addErrorCase('Invoices with missing contract no.', sErrorDescription);
        }

        if (!listImportPaymentsWhichContractCouldNotBeFound.isEmpty()) {
            String sErrorDescription = 'The following contract no. from import payments could not be found:' +
                '• ' + String.join(listImportPaymentsWhichContractCouldNotBeFound, '\n• ');
            this.addErrorCase('Invoices\' contract no. not found', sErrorDescription);
        }

        if (!this.errorCases.isEmpty()) {
            System.debug(DEBUG_HERE + 'Cases created: ' + this.errorCases);
            if (bCreateCases) insert this.errorCases;
        }
    }

    /**
     * Get Bonus__c IDs from an import string
     */
    private Set<Id> getBonusIdsFromString(String bonusIdString) {

        Set<Id> lsetBonusIds = new Set<Id>();

        if (!this.isEmptyString(bonusIdString)) {

            for (String sBonusId : bonusIdString.split(',')) {

                sBonusId = sBonusId.trim();
                Id idBonus;

                if (sBonusId.length() >= 15) {
                    try {
                        idBonus = (Id)sBonusId;
                        lsetBonusIds.add(sBonusId);
                    }
                    catch (Exception e) {}
                }
            }
        }
        return lsetBonusIds;
    }


    /**
     * Fetch invoices by type, year and month and
     * return them as a list of InvoiceNo to Payment__c
     */
    public Map<String,Payment__c> fetchInvoicesAsPaymentObjects(String type, Integer year, Integer month, Integer maxLogMultiple, Boolean createCases) {

        String DEBUG_HERE = DEBUG_HEADER + 'fetchInvoicesAsPaymentObjects() - ';

        Map<String,Payment__c> mapInvoiceNoToPayment = new Map<String,Payment__c>();

        LumenazaApi.LumenazaApiResponse oLumenazaResponse = this.lumenazaApi.fetchInvoices(type, year, month);

        this.defaultErrorCaseDescription += '\nAPI: ' + this.LumenazaApi.getLastCalloutInfo().get('info');

        if (oLumenazaResponse.success == false) {
            System.debug(DEBUG_HERE + 'Error: ' + oLumenazaResponse.error + ' | Request info: ' + oLumenazaResponse.requestInfo);
            return NULL;
        }

        String sCSV = oLumenazaResponse.responseBody;

        this.defaultErrorCaseDescription += '\n\nCSV extract:\n';
        this.defaultErrorCaseDescription += sCSV.length() > 3000 ? sCSV.substring(0,3000) : sCSV;

        // CSV as map with headers
        List<Map<String,String>> listInvoiceMap =  this.parseCSV(sCSV);

        // Create Payment__c objects
        // Map Lumenaza fields to Payment__c fields
        if (listInvoiceMap != NULL && !listInvoiceMap.isEmpty()) {

            System.debug(DEBUG_HERE + 'Parsed ' + listInvoiceMap.size() + ' row(s) from CSV: ' + listInvoiceMap);

            Map<String, Schema.SObjectField> mapPaymentSchemaFields = Schema.SObjectType.Payment__c.fields.getMap();

            Map<String,String> mapMapping = this.getInvoiceMapping(type);

            try {

                for (Map<String,String> mapInvoice : listInvoiceMap) {

                    Payment__c oPayment = new Payment__c(
                        RecordTypeId = RECORD_TYPE_ID_PAYMENT
                    );

                    // Map fields
                    for (String sInvoiceField : mapMapping.keySet()) {

                        String sPaymentField = mapMapping.get(sInvoiceField);

                        if (!this.isEmptyString(sPaymentField) && mapInvoice.containsKey(sInvoiceField)) {

                            String sFieldValue = mapInvoice.get(sInvoiceField);
                            String sFieldType = String.valueOf(mapPaymentSchemaFields.get(sPaymentField).getDescribe().getType());

                            System.debug(DEBUG_HERE + sPaymentField + ': ' + sFieldType + ' "' + sFieldValue + '"');

                            if (sFieldType == 'DATE') {
                                oPayment.put(sPaymentField, convertToDate(sFieldValue));
                                continue;
                            }
                            if (sFieldType == 'DOUBLE') {
                                oPayment.put(sPaymentField, Decimal.valueOf(sFieldValue));
                                continue;
                            }

                            oPayment.put(sPaymentField, mapInvoice.get(sInvoiceField));
                        }
                    }

                    if (this.isEmptyString(oPayment.Lumenaza_InvoiceNo__c)) {
                        System.debug(DEBUG_HERE + 'Error: Imported record has no invoice no. set and will be skipped!');
                    }
                    else if (mapInvoiceNoToPayment.containsKey(oPayment.Lumenaza_InvoiceNo__c)) {
                        System.debug(DEBUG_HERE + 'Error: Duplicate with duplicate invoice no. "' + oPayment.Lumenaza_InvoiceNo__c + '"!');
                    }
                    else {
                        mapInvoiceNoToPayment.put(oPayment.Lumenaza_InvoiceNo__c, oPayment);
                    }

                    System.debug(DEBUG_HERE + '------------------------------------');
                }
            }
            catch (Exception e) {
                String sSubject = 'Problem while parsing import CSV';
                this.addErrorCase(sSubject, 'There was a problem parsing the current CSV. Maybe invalid CSV format: ' + e.getMessage() + ' (' + e.getStackTraceString());
                if (createCases) {
                    insert this.errorCases;
                    System.debug(DEBUG_HERE + 'Error: ' + sSubject + ' - created a case');
                }
                mapInvoiceNoToPayment.clear();
            }
        }
        else {
            System.debug(DEBUG_HERE + 'No rows parsed from CSV');
        }

        // Debug map
        if (!mapInvoiceNoToPayment.isEmpty()) {

            Integer i = 0;
            System.debug(DEBUG_HERE + 'Created Payment__c map:');

            for (String sInvoiceNo : mapInvoiceNoToPayment.keySet()) {

                i++;

                if (maxLogMultiple > 0 && i == maxLogMultiple) {
                    System.debug(DEBUG_HERE + 'Cut list at item #' + maxLogMultiple);
                    break;
                }

                System.debug(DEBUG_HERE + '#' + i + ' Invoice No. ' + sInvoiceNo + ': ' + mapInvoiceNoToPayment.get(sInvoiceNo));
            }
        }

        return mapInvoiceNoToPayment;
    }

    /**
     * Convert CSV date to Date
     */
    public static Date convertToDate(String csvDate) {

        Matcher matches = Pattern.compile('^([0-9]{1,2})[.]([0-9]{1,2})[.]([0-9]{4})').matcher(csvDate);

        if (matches.find()) {
            return Date.newinstance(
                Integer.valueOf(matches.group(3)),
                Integer.valueOf(matches.group(2)),
                Integer.valueOf(matches.group(1))
            );
        }

        return NULL;
    }

    /**
     * Returns the mapping for a CSV type
     */
    private Map<String,String> getInvoiceMapping(String type) {

        Map<String,String> mapMapping = new Map<String,String>();

        mapMapping = INVOICE_TO_PAYMENT_MAPPING.get('_common');

        if (INVOICE_TO_PAYMENT_MAPPING.containsKey(type)) {
            // Set individual fields or overwrite existing mapping
            for (String sInvoiceField : INVOICE_TO_PAYMENT_MAPPING.get(type).keySet()) {
                mapMapping.put(sInvoiceField, INVOICE_TO_PAYMENT_MAPPING.get(type).get(sInvoiceField));
            }
        }

        return mapMapping;
    }

    /**
     * Parses CSV and returns it as map with headers
     */
    private List<Map<String,String>> parseCSV(String csvData) {

        CsvReader oCsvReader = new CsvReader(csvData, ';');

        // Get CSV values as map with headers
        List<Map<String,String>> listCsvMap = oCsvReader.getMapWithHeaders();

        return listCsvMap;
    }

    /**
     * Prepare an error case
     */
    public Case addErrorCase(String subject, String description) {

        Map<String,String> mapReturn = new Map<String,String>();

        Id idRecordType = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Case', 'eServices');

        description += '\n\n' + this.defaultErrorCaseDescription;

        //1.7.0 - remove stage
        Case oCase = new Case(
            Subject        = subject.length() > 255 ? subject.substring(0,255) : subject,
            Description    = description.length() > 32000 ? description.substring(0, 31950) + ' ...' : description,
            RecordTypeId   = idRecordType,
            Subcategory__c = 'invoiceSync',
            Status         = 'Open',
            Priority       = 'Low',
            Type           = 'Problem'
        );

        this.errorCases.add(oCase);
        
        return oCase;
    }

    private Boolean isEmptyString(String stringToCheck) {
        return (stringToCheck == NULL || stringToCheck.trim().length() == 0);
    }

    class LumenazaContractInvoiceSynchronizerException extends Exception {}
}