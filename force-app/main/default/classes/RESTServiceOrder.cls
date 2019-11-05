/**
 * Order API
 *
 * This is the order endpoint mainly used for incoming
 * commercetools orders as JSON.
 *
 * Changelog
 * ---------
 *
 * v1.0.0   2018-02-02  Marko Schmalenbach          Initial draft
 * v1.1.0   2018-02-20  Marko Schmalenbach          - Added "preventPersistence" parameter to toggle persistence
 *                                                  - Filter only OrderInputDefinitionJunctions with IsActive__c set
 *                                                  - OrderInputDefinitionJunction.IsFinallyRequired__c taken into account
 * v1.2.0   2018-02-22  Marko Schmalenbach          Added OrderSource__c at Opportunity
 * v1.3.0   2018-03-16  Andrey Safronenko           Added Contract creation (SOBCRM-1156)
 * v1.4.0   2018-04-26  Polina Tsuban-Drobot        Contract creation transferred to ContractCreatorFromOpportunityCtrl (SOBCRM-1163)
 * v1.5.0   2018-04-30  Polina Tsuban-Drobot        Added Phone retrieve (SOBCRM-1181)
 * v1.6.0   2018-05-07  Marko Schmalenbach          Added special handling of OrderInputDefinitions of type "price" (SOBCRM-1188)
 * v1.7.0   2018-05-09  Marko Schmalenbach          Added special handling of OrderInputDefinitions of type "attachment" (SOBCRM-1169)
 * v1.8.0   2018-06-15  Marko Schmalenbach          Added special handling of OrderInputDefinitions of type "termsAndConditions" (SOBCRM-1189)
 * v1.9.0   2018-06-19  Marko Schmalenbach          saveAttachmentToObject(): Extract attachment name from basename of URL if none given
 * v1.10.0  2018-06-20  Marko Schmalenbach          Fix in customFieldsToOrderInputDefinitionValues(): If an Order Input Definition is not
 *                                                      required but validation is configured and value is not empty the validation will be processed
 *                                                  Make use of String.isBlank() :)
 * v1.11.0  2018-07-02  Marko Schmalenbach          Updated DuplicateCheckHandler to DuplicateCheckHandlerv3
 * v1.12.0  2018-07-04  Marko Schmalenbach          Return relevant SObjects created (SOBCRM-1219)
 * v1.13.0  2018-09-19  Marko Schmalenbach          Set Country and Language for Terms and Conditions search (SOBCRM-1260)
 * v1.13.1  2018-09-20  Marko Schmalenbach          Added output of TermsAndConditions__c, TermsAndConditionsTypeNote__c of Order Input Definition Values
 * v2.0.0   2018-10-11  Marko Schmalenbach          SOBCRM-1256 and SOBCRM-1271 (Save Hardware especially for Australian market)
 *                                                  - Filter only OrderInputDefinitionJunctions with IsFinallyActive__c set
 *                                                  - Create Order with OrderItems from Hardware Product
 *                                                  - Target Fields are also handled on Opportunity, OpportunityLineItem, Order, OrderItem, Account, Contact
 *                                                  - Set Opportunity.IsRestServiceOrderProcessed__c at the end of processing so that other processes can react
 * v2.1.0   2018-10-16  Marko Schmalenbach          Fill fields (SOBCRM-1271):
 *                                                  - Opportunity.WebOrderTotalPrice__c
 *                                                  - OpportunityLineItem.WebOrderUnitPrice__c
 *                                                  - OpportunityLineItem.WebOrderTotalPrice__c
 * v2.1.1   2018-10-17  Marko Schmalenbach          Set UnitPrice for OpportunityLineItems instead of TotalPrice
 * v2.2.0   2018-10-18  Marko Schmalenbach          - Opportunity's Company__c, Salutation__c, FirstName__c, LastName__c are not set from Billing Address
 *                                                  - Opportunity.Phone__c and Opportunity.Email__c are set from Billing Address if present. If not those
 *                                                    of Shipping Address are taken
 * v2.2.1   2018-10-24  Marko Schmalenbach          - Added ShippingPhone__c
 *                                                  - Propagate WebOrderUnitPrice__c and WebOrderTotalPrice__c for debugging
 * v2.3.0   2018-10-30  Marko Schmalenbach          Set Opportunity.OrderConfirmationAllowedToBeSent__c to true at the end of the process
 * v2.3.1   2019-02-11  Marko Schmalenbach          Fix: Removed MAP_COUNTRY_FLAGS for displaying country flag in Opportunity name as this cannot be shown in Windoze :/
 *
 * @author  Marko Schmalenbach <marko@die-interaktiven.de>
 * @see RESTServiceOrder_Test
 */
@RestResource(urlMapping='/order/*')
global with sharing class RESTServiceOrder {

    private static final String DEBUG_HEADER = 'RESTServiceOrder.';

    private static Opportunity oOpportunity;
    private static Order oOrder;

    public static final String PRODUCT_RECORD_TYPE_PAYMENT         = 'Payment';
    public static final String PRODUCT_RECORD_TYPE_BUNDLE          = 'Bundle';
    public static final String PRODUCT_RECORD_TYPE_ORDER           = 'DirectSales';
    public static final String PRODUCT_RECORD_TYPE_ESERVICE        = 'eService';
    public static final String PRODUCT_RECORD_TYPE_ESERVICE_BUNDLE = 'eServiceBundleProduct';
    public static final String PRODUCT_RECORD_TYPE_HARDWARE        = 'Standard';

    public static final String DEFAULT_CURRENCY_CODE = 'EUR';
    public static final String DEFAULT_LANGUAGE_CODE = 'de';
    public static final String DEFAULT_COUNTRY_CODE  = 'DE';

    public static Boolean suppressDebug = false;

    /**
     * Handle POST
     *
     * Order creation
     */
    @HttpPost
    global static Response handlePost() {

        String DEBUG_HERE = DEBUG_HEADER + 'handlePost() - ';

        RestRequest oRequest = RestContext.request;

        // Default status
        RestContext.response.statusCode = 200;

        // POST data
        // Expects the data to be of content-type application/json!
        Blob body = oRequest.requestBody;
        String sOrderAsJson = body.toString();

        System.debug(DEBUG_HERE + 'JSON: ' + sOrderAsJson);

        // Inner class to have an own context
        RESTServiceOrder.OrderProcessor oOrderProcessor = new RESTServiceOrder.OrderProcessor(sOrderAsJson, (oRequest.params.get('preventPersistence') == '1'));
        RESTServiceOrder.Response oResponse = oOrderProcessor.process();

        return oResponse;
    }

    /**
     * OrderProcessor
     */
    global class OrderProcessor {

        private String DEBUG_HEADER_INNER = 'OrderProcessor.';

        private String sOrderJson;

        private Map<String,Object> mapOrder = new Map<String,Object>();

        private String sOrderLanguageCode;

        private String sOrderCountryCode;

        private RESTServiceOrder.Response oResponse = new RESTServiceOrder.Response();

        private ConstraintValidator oConstraintValidator = new ConstraintValidator();

        private Boolean bPreventPersistence = false;

        private String sOrderCurrency = 'EUR';

        private Map<String,Map<String,String>> mapAttachments = new Map<String,Map<String,String>>();

        public OrderProcessor(String order) {
            this(order, false);
        }

        public OrderProcessor(String order, Boolean preventPersistence) {
            this.sOrderJson = order;
            this.bPreventPersistence = preventPersistence;
        }

        /**
         * Process Order
         *
         * @return
         */
        public RESTServiceOrder.Response process() {

            String DEBUG_HERE = DEBUG_HEADER_INNER + 'process() - ';

            Savepoint eineSchritteSuruck;

            // To prevent Exception "You have already created Savepoints.
            // You cannot make callout after creating a Savepoint" at unit testing
            if (!Test.isRunningTest()) {
                eineSchritteSuruck = Database.setSavepoint();
            }

            while (true) {

                try {

                    if (this.sOrderJson.length() == 0) {
                        this.oResponse.setError('Empty requrest', 'EMPTY_REQUEST', 400);
                        break;
                    }

                    // Convert JSON to a map
                    this.mapOrder = (Map<String,Object>)JSON.deserializeUntyped(this.sOrderJson);

                    this.oResponse.addDebug(DEBUG_HERE + 'PERSISTENCE: ' + (this.bPreventPersistence ? 'OFF' : 'ON'));

                    // Get line items
                    List<Object> listLineItems = (List<Object>)ConstraintValidator.resolvePath(this.mapOrder, 'lineItems');
                    // There might be also Custom Line Items
                    List<Object> listCustomLineItems = (List<Object>)ConstraintValidator.resolvePath(this.mapOrder, 'customLineItems');

                    if (listLineItems.isEmpty()) {
                        this.oResponse.setError('Order contains no line items', 'NO_LINE_ITEMS_FOUND', 400);
                        break;
                    }

                    // Get recordTypes
                    Map<String,Map<String,Id>> mapRecordTypes = DiaUtilities.getRecordTypeMap(new List<String>{'Opportunity'});

                    // Get customer addresses
                    Map<String,Object> mapBillingAddress = (Map<String,Object>)ConstraintValidator.resolvePath(this.mapOrder, 'billingAddress');
                    Map<String,Object> mapShippingAddress = (Map<String,Object>)ConstraintValidator.resolvePath(this.mapOrder, 'shippingAddress');

                    // Get language, country and currency
                    this.sOrderLanguageCode = (String)this.mapOrder.get('locale');
                    this.sOrderCountryCode  = (String)this.mapOrder.get('country');
                    this.sOrderCurrency     = (String)ConstraintValidator.resolvePath(this.mapOrder, 'totalPrice.currencyCode');

                    this.oResponse.addDebug(
                        DEBUG_HERE + 'Received Codes - ' +
                            'Language: "' + this.sOrderLanguageCode + '", ' +
                            'Country: "' + this.sOrderCountryCode + '", ' +
                            'Currency: "' + this.sOrderCurrency + '"'
                    );

                    if (String.isBlank(this.sOrderLanguageCode)) {
                        this.sOrderLanguageCode = DEFAULT_LANGUAGE_CODE;
                    }
                    if (String.isBlank(this.sOrderCountryCode)) {
                        this.sOrderCountryCode = DEFAULT_COUNTRY_CODE;
                    }
                    if (String.isBlank(this.sOrderCurrency)) {
                        this.sOrderCurrency = DEFAULT_CURRENCY_CODE;
                    }

                    if (!Pattern.matches('[a-z]{2}', this.sOrderLanguageCode)) {
                        this.oResponse.setError('Invalid or missing language code in "locale"', 'INVALID_LANGUAGE_CODE', 400);
                        break;
                    }
                    if (!Pattern.matches('[A-Z]{2}', this.sOrderCountryCode)) {
                        this.oResponse.setError('Invalid or missing country code in "country"', 'INVALID_COUNTRY_CODE', 400);
                        break;
                    }
                    if (!Pattern.matches('[A-Z]{3}', this.sOrderCurrency)) {
                        this.oResponse.setError('Invalid or missing currency code in "totalPrice.currencyCode"', 'INVALID_CURRENCY_CODE', 400);
                        break;
                    }

                    this.oResponse.addDebug(
                        DEBUG_HERE + 'Final Codes - ' +
                            'Language: "' + this.sOrderLanguageCode + '", ' +
                            'Country: "' + this.sOrderCountryCode + '", ' +
                            'Currency: "' + this.sOrderCurrency + '"'
                    );

                    //-------------------------------------------------------------------------------------
                    // Opportunity
                    //-------------------------------------------------------------------------------------

                    // Get standard pricebook (price doesn't really matter here ...)
                    Pricebook2 oPricebook2 = [SELECT Id, Name, CurrencyIsoCode FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1];
                    Id idStandardPricebook = oPricebook2.Id;

                    this.oResponse.addDebug(DEBUG_HERE + 'Opportunity Pricebook: ' + oPricebook2.Name + ' (' + oPricebook2.Id + ') in ' + oPricebook2.CurrencyIsoCode);

                    // Create Opportunity to handle the order
                    Integer iMaxOrderSourceSize = 131072;
                    Decimal fWebOrderTotalPrice = 0;

                    if (ConstraintValidator.resolvePath(this.mapOrder, 'totalPrice.centAmount') != null) {
                        fWebOrderTotalPrice = Double.valueOf(ConstraintValidator.resolvePath(this.mapOrder, 'totalPrice.centAmount'))/100;
                    }

                    oOpportunity = new Opportunity(
                        RecordTypeId            = mapRecordTypes.get('Opportunity').get('WebOrder'),
                        Name                    = 'Web Order ' + this.sOrderCountryCode + ' ' + (System.now().formatGmt('yyyy-MM-dd HH:mm:ss') + ' GMT'),
                        StageName               = 'Requested',
                        CloseDate               = System.today().addDays(30),
                        RecordSource__c         = 'Web',
                        Language__c             = this.sOrderLanguageCode,
                        TargetCountry__c        = this.sOrderCountryCode,
                        OrderSource__c          = this.sOrderJson.length() > iMaxOrderSourceSize ? this.sOrderJson.substring(0, iMaxOrderSourceSize) : this.sOrderJson,
                        Pricebook2Id            = idStandardPricebook,
                        CurrencyIsoCode         = this.sOrderCurrency,
                        WebOrderTotalPrice__c   = fWebOrderTotalPrice
                    );

                    // Email and Phone need special treatment
                    // (for german orders Shipping Address those fields are currently
                    // always set as this is the main address)
                    String sPersonPhone;
                    String sPersonEmail;

                    // Set billing address
                    if (mapBillingAddress != null && !mapBillingAddress.isEmpty()) {

                        sPersonEmail = String.valueOf(mapBillingAddress.get('email'));
                        sPersonPhone = String.valueOf(mapBillingAddress.get('phone'));

                        // Common fields set by billing address information
                        oOpportunity.Company__c                 = String.valueOf(mapBillingAddress.get('company'));
                        oOpportunity.Salutation__c              = String.valueOf(mapBillingAddress.get('salutation'));
                        oOpportunity.FirstName__c               = String.valueOf(mapBillingAddress.get('firstName'));
                        oOpportunity.LastName__c                = String.valueOf(mapBillingAddress.get('lastName'));

                        oOpportunity.BillingStreet__c           = String.valueOf(mapBillingAddress.get('streetName'));
                        oOpportunity.BillingStreetNo__c         = String.valueOf(mapBillingAddress.get('streetNumber'));
                        oOpportunity.BillingPostalCode__c       = String.valueOf(mapBillingAddress.get('postalCode'));
                        oOpportunity.BillingCity__c             = String.valueOf(mapBillingAddress.get('city'));
                        oOpportunity.BillingCountryIsoCode__c   = String.valueOf(mapBillingAddress.get('country'));
                        oOpportunity.BillingState__c            = this.extractStateIsoCodeFromCombined(String.valueOf(mapBillingAddress.get('state')));
                        oOpportunity.BillingAdditional__c       = String.valueOf(mapBillingAddress.get('additionalStreetInfo'));
                    }

                    // Set shipping address
                    if (mapShippingAddress != null && !mapShippingAddress.isEmpty()) {

                        // Only if not set yet
                        if (String.isBlank(sPersonEmail)) {
                            sPersonEmail = String.valueOf(mapShippingAddress.get('email'));
                        }
                        if (String.isBlank(sPersonPhone)) {
                            sPersonPhone = String.valueOf(mapShippingAddress.get('phone'));
                        }

                        // Shipping fields
                        oOpportunity.ShippingCompany__c         = String.valueOf(mapShippingAddress.get('company'));
                        oOpportunity.ShippingSalutation__c      = String.valueOf(mapShippingAddress.get('salutation')); // Text
                        oOpportunity.ShippingSalutation2__c     = String.valueOf(mapShippingAddress.get('salutation')); // Picklist
                        oOpportunity.ShippingFirstName__c       = String.valueOf(mapShippingAddress.get('firstName'));
                        oOpportunity.ShippingLastName__c        = String.valueOf(mapShippingAddress.get('lastName'));
                        oOpportunity.ShippingStreet__c          = String.valueOf(mapShippingAddress.get('streetName'));
                        oOpportunity.ShippingStreetNo__c        = String.valueOf(mapShippingAddress.get('streetNumber'));
                        oOpportunity.ShippingPostalCode__c      = String.valueOf(mapShippingAddress.get('postalCode'));
                        oOpportunity.ShippingCity__c            = String.valueOf(mapShippingAddress.get('city'));
                        oOpportunity.ShippingCountryIsoCode__c  = String.valueOf(mapShippingAddress.get('country'));
                        oOpportunity.ShippingState__c           = this.extractStateIsoCodeFromCombined(String.valueOf(mapShippingAddress.get('state')));
                        oOpportunity.ShippingAdditional__c      = String.valueOf(mapShippingAddress.get('additionalStreetInfo'));
                        oOpportunity.ShippingPhone__c           = String.valueOf(mapShippingAddress.get('phone'));
                    }

                    // Set Email and Phone
                    oOpportunity.Email__c = sPersonEmail;
                    oOpportunity.Phone__c = sPersonPhone;

                    insert oOpportunity;

                    // SOBCRM-1184 Create Account with ID Check to prevent duplicates
                    // Updated 2018-07-02 to DuplicateCheckHandlerv3
                    DuplicateCheckHandlerv3 oDuplicateCheckHandler = new DuplicateCheckHandlerv3(new List<Opportunity>{ oOpportunity });

                    try {
                        // In our case there is only one element in the map and
                        // key is the Opportunity ID here
                        Map<Id,Map<String,Id>> mapFoundAccountContactForOpportunityId = oDuplicateCheckHandler.handleObjectsv2();
                        Map<String,Id> mapAccountAndContactIds = mapFoundAccountContactForOpportunityId.get(oOpportunity.Id);

                        oOpportunity.AccountId         = mapAccountAndContactIds.get('Account');
                        oOpportunity.PrimaryContact__c = mapAccountAndContactIds.get('Contact'); // will later be Contract.CustomerSignedId

                        this.oResponse.addDebug(DEBUG_HERE + 'Set Opportunity\'s AccountId to "' + oOpportunity.AccountId + '" and PrimaryContact__c to "' + oOpportunity.PrimaryContact__c + '"');

                        update oOpportunity;
                    }
                    catch (Exception e) {
                        this.oResponse.addDebug(DEBUG_HERE + 'Can\'t set Account for new Opportunity: ' + e.getMessage() + ' (' + e.getStackTraceString() + ')');
                    }

                    //-------------------------------------------------------------------------------------
                    // Get Product2 objects according to line items of order
                    //-------------------------------------------------------------------------------------
                    Map<String,Map<String,Object>> mapLineItemsBySKU = new Map<String,Map<String,Object>>();
                    Set<String> lsetProductSKUs = new Set<String>();

                    // Collect SKUs

                    // Regular line items (= visible Product at website)
                    for (Object oLineItemObject : listLineItems) {

                        Map<String,Object> mapLineItem = (Map<String,Object>)oLineItemObject;
                        String sProductSKU = (String)ConstraintValidator.resolvePath(mapLineItem, 'variant.sku');
                        mapLineItemsBySKU.put(sProductSKU, mapLineItem);
                        lsetProductSKUs.add(sProductSKU);
                    }

                    // Custom line items (= invisible Product at website)
                    if (listCustomLineItems != null && !listCustomLineItems.isEmpty()) {

                        for (Object oLineItemObject : listCustomLineItems) {

                            Map<String,Object> mapLineItem = (Map<String,Object>)oLineItemObject;
                            String sProductSKU = (String)mapLineItem.get('slug');
                            mapLineItemsBySKU.put(sProductSKU, mapLineItem);
                            lsetProductSKUs.add(sProductSKU);
                        }
                    }

                    // Get all Products and bundled Product along with their Order Input Definitions.
                    // This works recursively!
                    Map<String,Product2> mapProductBySKU = new Map<String,Product2>();
                    this.getBundleProductsForSKUs(mapLineItemsBySKU.keySet(), mapProductBySKU);

                    if (mapProductBySKU.isEmpty()) {
                        this.oResponse.setError('No products found for SKUs', 'NO_PRODUCTS_FOUND', 400);
                        break;
                    }

                    // Check if all order products exist
                    List<String> listNotFoundSKUs = new List<String>();

                    // BundleProduct SKU -> MasterProduct SKU
                    Set<String> lsetBundleProductWithCoexistingMasterProduct = new Set<String>();
                    Set<Id> lsetOrderInputDefinitionIds = new Set<Id>();

                    Integer iEServiceCount = 0;

                    for (Product2 oProduct : mapProductBySKU.values()) {

                        if (oProduct.RecordType.DeveloperName == PRODUCT_RECORD_TYPE_ESERVICE) {

                            iEServiceCount++;

                            if (iEServiceCount > 1) {
                                this.oResponse.setError('There can be only ONE eService Product in a order', 'MORE_THAN_ONE_ESERVICE_PRODUCT', 400);
                                break;
                            }
                        }


                        // ⚠️ Only for NON financing products
                        if (oProduct.RecordType.DeveloperName != PRODUCT_RECORD_TYPE_PAYMENT) {

                            if (oProduct.PricebookEntries.isEmpty()) {
                                this.oResponse.setError('Internal Error: Product "' + oProduct.StockKeepingUnit + '" has no standard price configured', 'PRODUCT_WITHOUT_DEFAULT_PRICE', 500);
                                break;
                            }

                            // Check on bundled products
                            if (oProduct.BundledProducts__r.size() > 0) {
                                for (ProductJunction__c oBundleProductJunction : oProduct.BundledProducts__r) {
                                    lsetBundleProductWithCoexistingMasterProduct.add(oBundleProductJunction.BundleProduct__r.StockKeepingUnit);
                                }
                            }
                        }

                        // Collect OrderInputDefinition IDs
                        if (!oProduct.OrderInputDefinitionJunctions__r.isEmpty()) {
                            for (OrderInputDefinitionJunction__c oOrderInputDefinitionJunction : oProduct.OrderInputDefinitionJunctions__r) {
                                lsetOrderInputDefinitionIds.add(oOrderInputDefinitionJunction.OrderInputDefinition__c);
                            }
                        }
                    }

                    for (String sSKU : mapLineItemsBySKU.keySet()) {
                        if (!mapProductBySKU.containsKey(sSKU)) {
                            listNotFoundSKUs.add(sSKU);
                        }
                    }

                    if (!listNotFoundSKUs.isEmpty()) {
                        this.oResponse.setError('No products found for SKU(s): ' + String.join(listNotFoundSKUs, ', '), 'SOME_PRODUCTS_NOT_FOUND', 400);
                        break;
                    }

                    // Get Constraints for OrderInputDefinitions used by ordered products
                    if (!lsetOrderInputDefinitionIds.isEmpty()) {
                        this.oConstraintValidator.init(lsetOrderInputDefinitionIds);
                    }

                    //-------------------------------------------------------------------------------------
                    // Handle line items
                    //-------------------------------------------------------------------------------------
                    List<OpportunityLineItem> listOpportunityLineItems = new List<OpportunityLineItem>();
                    List<OrderItem> listOrderItems = new List<OrderItem>();

                    // Map Product ID -> Order Input Definition Values map with input field ID as key
                    Map<Id, Map<String, OrderInputDefinitionValue__c>> mapOrderInputDefinitionValuesByProductId = new Map<Id, Map<String, OrderInputDefinitionValue__c>>();

                    Map<String,Object> mapCustomFieldsCheckout = (Map<String,Object>)ConstraintValidator.resolvePath(this.mapOrder, 'custom.fields');

                    /*
                    *
                    * - commercetools sends bundle Product
                    * - Bundled Products can and should be sent if Order Input Definitions value in Domain "Product" want to be set
                    * - Product bundled SKUs are fetched because some of them will go to
                    *     - Opp Line Item and some to
                    *     - Order Item
                    * - All Order Input Definition values for those products are fetched
                    * - Only ONE eService Product per Order allowed! (Only 1 Opportunity)
                    */
                    this.oResponse.addDebug(DEBUG_HERE + 'SKUs to handle: ' + mapProductBySKU.keySet());

                    for (String sSKU : mapProductBySKU.keySet()) {

                        Boolean bIsOrderLineItem = mapLineItemsBySKU.containsKey(sSKU);
                        Product2 oProduct = mapProductBySKU.get(sSKU);

                        this.oResponse.addDebug(DEBUG_HERE + '----------------------------------------------------------------');
                        this.oResponse.addDebug(DEBUG_HERE + 'LINE ITEM WITH SKU "' + sSKU);
                        this.oResponse.addDebug(DEBUG_HERE + '----------------------------------------------------------------');
                        this.oResponse.addDebug(DEBUG_HERE + 'Product: ' + oProduct.Name + ' (' + oProduct.Id + ', type "' + oProduct.RecordType.DeveloperName + '")');
                        this.oResponse.addDebug(DEBUG_HERE + 'Source: ' + (bIsOrderLineItem ? 'Order Product' : 'Resolved Product via Bundle'));

                        //--------------------------------------------------------
                        // Create Line Items for Opportunity and/or Order
                        //--------------------------------------------------------
                        Map<String,Object> mapLineItem = mapLineItemsBySKU.get(sSKU);

                        Integer iQuantity = 1;
                        Decimal fUnitPrice = oProduct.PricebookEntries.get(0).UnitPrice;
                        Decimal fUnitPriceOrder = 0;
                        Decimal fTotalPriceOrder = 0;

                        // EVERY product including a bundled one goes to an OpportunityLineItem!
                        if (bIsOrderLineItem) {

                            iQuantity = Integer.valueOf(mapLineItem.get('quantity'));

                            if (ConstraintValidator.resolvePath(mapLineItem, 'price.value.centAmount') != null) {
                                fUnitPriceOrder = Double.valueOf(ConstraintValidator.resolvePath(mapLineItem, 'price.value.centAmount'))/100;
                            }
                            if (ConstraintValidator.resolvePath(mapLineItem, 'totalPrice.centAmount') != null) {
                                fTotalPriceOrder = Double.valueOf(ConstraintValidator.resolvePath(mapLineItem, 'totalPrice.centAmount'))/100;
                            }
                        }

                        PricebookEntry oCurrentPricebookEntry = oProduct.PricebookEntries.get(0);

                        OpportunityLineItem oOpportunityLineItem = new OpportunityLineItem(
                            OpportunityId         = oOpportunity.Id,
                            PricebookEntryId      = oCurrentPricebookEntry.Id,
                            Product2Id            = oProduct.Id,
                            Quantity              = iQuantity,
                            UnitPrice             = fUnitPrice,
                            WebOrderUnitPrice__c  = fUnitPriceOrder,
                            WebOrderTotalPrice__c = fTotalPriceOrder,
                            Description           = 'SKU: ' + sSKU
                        );

                        this.oResponse.addDebug(DEBUG_HERE + 'Opportunity Line Item "' + sSKU + '" Pricebook: ' +
                            oCurrentPricebookEntry.Pricebook2.Name + ' (' + oCurrentPricebookEntry.Pricebook2Id + ') in ' + oCurrentPricebookEntry.CurrencyIsoCode);

                        listOpportunityLineItems.add(oOpportunityLineItem);

                        // All Hardware items also go to OrderItem objects
                        if (oProduct.RecordType.DeveloperName == PRODUCT_RECORD_TYPE_HARDWARE) {

                            OrderItem oOrderItem = new OrderItem(
                                Product2Id       = oProduct.Id,
                                Quantity         = iQuantity,
                                PricebookEntryId = oProduct.PricebookEntries.get(0).Id,
                                UnitPrice        = fUnitPrice,
                                Description      = 'SKU: ' + sSKU
                            );

                            listOrderItems.add(oOrderItem);
                        }

                        //--------------------------------------------------------
                        // Create Order Input Definition Values
                        //--------------------------------------------------------
                        // Insert OrderDefinitionValues to write all customer input
                        // according to related OrderInputDefinitions
                        // Fields are mapped via mapCustomFieldsLineItem.key -> OrderInputDefinition__r.Id__c


                        // Create map of merged custom values
                        // As the custom field's ID is unique line item and checkout fields can be mixed up!
                        Map<String,Object> mapCustomFieldsLineItem = (Map<String,Object>)ConstraintValidator.resolvePath(mapLineItem, 'custom.fields');
                        Map<String,Object> mapCustomFields = new Map<String,Object>();

                        if (mapCustomFieldsLineItem != null) {
                            mapCustomFields.putAll(mapCustomFieldsLineItem);
                        }
                        if (mapCustomFieldsCheckout != null) {
                            mapCustomFields.putAll(mapCustomFieldsCheckout);
                        }

                        //------------------------------------------
                        // Custom values from "product" fields
                        //------------------------------------------
                        this.oResponse.addDebug(DEBUG_HERE + 'Find values for custom fields in LineItem (product specific fields)');
                        Map<String, OrderInputDefinitionValue__c> mapOrderInputDefinitionValuesLineItem = this.customFieldsToOrderInputDefinitionValues(
                            mapCustomFieldsLineItem,
                            oProduct,
                            'product',
                            mapCustomFields
                        );

                        if (this.oResponse.hasError()) {
                            break;
                        }

                        this.oResponse.addDebug(DEBUG_HERE + 'Values from "product" for current line item: ' + mapOrderInputDefinitionValuesLineItem.size());

                        //------------------------------------------
                        // Custom values from "checkout" fields
                        //------------------------------------------
                        // Those are also field configured at the Product2!
                        this.oResponse.addDebug(DEBUG_HERE + 'Find values for custom fields in Order (common checkout fields)');
                        Map<String, OrderInputDefinitionValue__c> mapOrderInputDefinitionValuesCheckout = this.customFieldsToOrderInputDefinitionValues(
                            mapCustomFieldsCheckout,
                            oProduct,
                            'checkout',
                            mapCustomFields
                        );

                        if (this.oResponse.hasError()) {
                            break;
                        }

                        this.oResponse.addDebug(DEBUG_HERE + 'Values from "checkout" for current line item: ' + mapOrderInputDefinitionValuesCheckout.size());

                        // Check if a custom field in "checkout" was already used for a line item
                        if (!mapOrderInputDefinitionValuesCheckout.isEmpty()) {
                            for (String sField : mapOrderInputDefinitionValuesLineItem.keySet()) {
                                if (mapOrderInputDefinitionValuesCheckout.containsKey(sField)) {
                                    this.oResponse.setError('Customer input field "' + sField + '" in checkout was already used for line item', 'DEFINITION_ID_ALREADY_IN_USE', 400);
                                    break;
                                }
                            }

                            // if not merge custom values from checkout with those from line items
                            mapOrderInputDefinitionValuesLineItem.putAll(mapOrderInputDefinitionValuesCheckout);
                        }
                        if (this.oResponse.hasError()) {
                            break;
                        }

                        // Add Order Input Definition Values to Product Id map for relating beneath
                        mapOrderInputDefinitionValuesByProductId.put(oProduct.Id, mapOrderInputDefinitionValuesLineItem);

                    } // end iteration over SKUs

                    if (this.oResponse.hasError()) {
                        break;
                    }

                    // Insert Opportunity- and OrderLineItems
                    if (!listOpportunityLineItems.isEmpty()) {
                        insert listOpportunityLineItems;
                    }

                    // Create Order
                    if (!listOrderItems.isEmpty()) {

                        oOrder = new Order(
                            AccountId       = oOpportunity.AccountId,
                            ShipToContactId = oOpportunity.PrimaryContact__c,
                            RecordTypeId    = DiaUtilities.getRecordTypeId('Order', PRODUCT_RECORD_TYPE_ORDER),
                            OpportunityId   = oOpportunity.Id,
                            Status          = 'Draft',
                            EffectiveDate   = System.today(),
                            Pricebook2Id    = idStandardPricebook,
                            CurrencyIsoCode = this.sOrderCurrency
                        );
                        insert oOrder;

                        // Relate to Order
                        for (OrderItem oOrderItem : listOrderItems) {
                            oOrderItem.OrderId = oOrder.Id;
                        }

                        insert listOrderItems;
                    }

                    //-------------------------------------------------------------------------------------
                    // Relate Order Input Definition Values
                    //-------------------------------------------------------------------------------------
                    // Related OrderInputDefinitionValues to their corresponding order source (OpportunityLine/OrderItem)
                    List<OrderInputDefinitionValue__c> listNewOrderInputDefinitionValues = new List<OrderInputDefinitionValue__c>();

                    // Opportunity Line Items
                    for (OpportunityLineItem oOpportunityLineItem : listOpportunityLineItems) {

                        List<OrderInputDefinitionValue__c> listDefinitionValuesToSetId = mapOrderInputDefinitionValuesByProductId.get(oOpportunityLineItem.Product2Id).values();

                        if (listDefinitionValuesToSetId.isEmpty()) {
                            continue;
                        }

                        for (OrderInputDefinitionValue__c oOrderInputDefinitionValue : listDefinitionValuesToSetId) {
                            // Currently it's not possible to have a real relation to an OpportunityLineItem (OLI)
                            // so the ID of the OLI is saved in a text field.
                            // To have a related list on Opportunity we relate the value with it
                            // by a master detail relationship. So if the Opportunity is deleted
                            // all OrderInputDefinitionValues will be too.
                            oOrderInputDefinitionValue.OpportunityLineItem__c = oOpportunityLineItem.Id;
                            oOrderInputDefinitionValue.Opportunity__c         = oOpportunity.Id;
                            listNewOrderInputDefinitionValues.add(oOrderInputDefinitionValue);
                        }
                    }

                    // Order Items
                    for (OrderItem oOrderItem : listOrderItems) {

                        List<OrderInputDefinitionValue__c> listDefinitionValuesToSetId = mapOrderInputDefinitionValuesByProductId.get(oOrderItem.Product2Id).values();

                        if (listDefinitionValuesToSetId.isEmpty()) {
                            continue;
                        }

                        for (OrderInputDefinitionValue__c oOrderInputDefinitionValue : listDefinitionValuesToSetId) {
                            oOrderInputDefinitionValue.OrderItem__c   = oOrderItem.Id;
                            oOrderInputDefinitionValue.Order__c       = oOrderItem.OrderId;
                            oOrderInputDefinitionValue.Opportunity__c = oOpportunity.Id;
                            listNewOrderInputDefinitionValues.add(oOrderInputDefinitionValue);
                        }
                    }

                    // Insert all OrderInputDefinitionValues
                    if (!listNewOrderInputDefinitionValues.isEmpty()) {
                        insert listNewOrderInputDefinitionValues;
                    }

                    this.oResponse.addDebug(DEBUG_HERE + 'Inserted ' + listNewOrderInputDefinitionValues.size() + ' OrderInputDefinitionValues');

                    //-------------------------------------------------------------------------------------
                    // Handle target fields
                    //-------------------------------------------------------------------------------------
                    List<Id> listOrderInputDefinitionValueIds = new List<Id>();
                    for (OrderInputDefinitionValue__c oOrderInputDefinitionValue : listNewOrderInputDefinitionValues) {
                        listOrderInputDefinitionValueIds.add(oOrderInputDefinitionValue.Id);
                    }

                    List<Object> listObjectsToUpdate = new List<Object>{
                        oOpportunity,
                        listOpportunityLineItems,
                        new Account(Id = oOpportunity.AccountId),
                        new Contact(Id = oOpportunity.PrimaryContact__c)
                    };

                    if (oOrder != null) {
                        listObjectsToUpdate.add(oOrder);
                    }
                    if (listOrderItems != null && !listOrderItems.isEmpty()) {
                        listObjectsToUpdate.add(listOrderItems);
                    }

                    Map<String, List<SObject>> mapSObjectsToUpdate = WebOrderUtil.updateSObjectsByOrderInputDefinitionValues(listOrderInputDefinitionValueIds, listObjectsToUpdate);

                    // Upsert SObjects (better would be to detect if they are dirty ...)
                    for (String sSObjectType : mapSObjectsToUpdate.keySet()) {

                        List<SObject> listSObjectsToUpsert = new List<SObject>();

                        // Upsert only if
                        for (SObject oSObject : mapSObjectsToUpdate.get(sSObjectType)) {
                            if (oSObject.getPopulatedFieldsAsMap().size() > 0) {
                                listSObjectsToUpsert.add(oSObject);
                            }
                        }

                        if (!listSObjectsToUpsert.isEmpty()) {

                            // Make a clean List<SObject> as otherwise this would raise an error
                            // stating that upsert cannot be done on a generic list!
                            List<SObject> listSObjects = (List<SObject>)Type.forName('List<' + sSObjectType + '>').newInstance();
                            listSObjects.addAll(listSObjectsToUpsert);

                            this.oResponse.addDebug(DEBUG_HERE + 'Target Field setting - Upserted ' + listSObjects.size() + ' object(s) of type "' + Type.forName(sSObjectType) + '"');
                            upsert listSObjects;
                        }
                    }

                    // Exception for Australia
                    // Set Subsidy Amount by OpportunityLineItemTriggerHandler.setAustralianSubsidyAmount()
                    // This due to the fact that the Subsidy Amount depends on the Capacity of the ordered
                    // Battery which is set on Opportunity.BatteryCapacity__c.
                    // The Subsidy is then calculated by oOpportunity.AustraliaCalculatedSubsidyAmount__c
                    // and must be overwrite the OpportunityLineItem's TotalPrice of Type "Subsidy".
                    if (this.sOrderCountryCode == 'AU') {
                        for (OpportunityLineItem oOpportunityLineItem : listOpportunityLineItems) {
                            oOpportunityLineItem.AustraliaCalculatedSubsidyAmountDoReset__c = true;
                        }
                        update listOpportunityLineItems;
                    }

                    //if (!this.oResponse.hasError()) { this.oResponse.setError('DEBUG CUT', 'TEST', 400); }
                    //break;

                    //-------------------------------------------------------------------------------------
                    // Handle attachments
                    //-------------------------------------------------------------------------------------
                    if (!this.mapAttachments.isEmpty()) {

                        // Check
                        String sAttachmentURLField = 'URL';
                        String sAttachmentNameField = 'name';

                        for (String sAttachmentGroupId : this.mapAttachments.keySet()) {

                            Map<String,String> mapAttachmentValues = this.mapAttachments.get(sAttachmentGroupId);

                            if (!mapAttachmentValues.containsKey(sAttachmentURLField) || String.isBlank(mapAttachmentValues.get(sAttachmentURLField))) {
                                this.mapAttachments.remove(sAttachmentGroupId);
                            }
                        }

                        if (!this.mapAttachments.isEmpty()) {

                            this.oResponse.addDebug(DEBUG_HERE + 'Adding '  + this.mapAttachments + ' attachment(s): ' + JSON.serializePretty(this.mapAttachments));

                            for (Map<String, String> mapAttachment : this.mapAttachments.values()) {
                                saveAttachmentToObject(
                                    mapAttachment.get(sAttachmentURLField),
                                    mapAttachment.get(sAttachmentNameField),
                                    oOpportunity.Id
                                );
                            }
                        }
                        else {
                            this.oResponse.addDebug(DEBUG_HERE + 'No attachments to add');
                        }
                    }

                    //----------------------------------------
                    // Return created SObjects
                    //----------------------------------------
                    // Created OpportunityLineItems
                    if (!listOpportunityLineItems.isEmpty()) {

                        List<Id> listOpportunityLineItemIds = new List<Id>();
                        for (OpportunityLineItem oOpportunityLineItem : listOpportunityLineItems) {
                            listOpportunityLineItemIds.add(oOpportunityLineItem.Id);
                        }

                        listOpportunityLineItems = [
                            SELECT
                                Id, Product2.StockKeepingUnit, UnitPrice, Quantity, TotalPrice, Product2.Family,
                                WebOrderUnitPrice__c, WebOrderTotalPrice__c
                            FROM OpportunityLineItem
                            WHERE Id IN :listOpportunityLineItemIds
                        ];
                    }

                    this.oResponse.addObjects('OpportunityLineItem', listOpportunityLineItems);

                    oOpportunity = [
                        SELECT
                            Id, Name, RecordType.DeveloperName, StageName, RecordSource__c, AccountId, PrimaryContact__c,
                            Email__c, Phone__c, Salutation__c, Company__c, FirstName__c, LastName__c,
                            ShippingStreet__c, ShippingStreetNo__c, ShippingPostalCode__c, ShippingCity__c, ShippingCountryIsoCode__c,
                            ShippingState__c, ShippingAdditional__c, ShippingSalutation__c, ShippingSalutation2__c, ShippingCompany__c,
                            BillingStreet__c, BillingStreetNo__c, BillingPostalCode__c, BillingCity__c, BillingCountryIsoCode__c,
                            BillingState__c, BillingAdditional__c, WebOrderTotalPrice__c
                        FROM Opportunity
                        WHERE Id = :oOpportunity.Id
                    ];
                    this.oResponse.addObject('Opportunity', oOpportunity);

                    // Created OrderInputDefinitionValues
                    if (!listNewOrderInputDefinitionValues.isEmpty()) {

                        listNewOrderInputDefinitionValues = [
                            SELECT Id, Name, CreatedDate, TermsAndConditions__c, TermsAndConditionsTypeNote__c, OrderInputDefinitionFieldId__c,
                                   OrderInputDefinitionLabel__c, OrderInputDefinition__c, Value__c,
                                   OrderItem__c, OpportunityLineItem__c
                            FROM OrderInputDefinitionValue__c
                            WHERE Id IN :listOrderInputDefinitionValueIds
                        ];

                        this.oResponse.addObjects('OrderInputDefinitionValue__c', listNewOrderInputDefinitionValues);
                    }

                    // Set IsRestServiceOrderProcessed__c so that other processes can react on it
                    oOpportunity.IsRestServiceOrderProcessed__c      = true;
                    oOpportunity.OrderConfirmationAllowedToBeSent__c = true;
                    update oOpportunity;
                }
                catch (Exception e) {
                    this.oResponse.setError(e.getTypeName() + ': ' + e.getMessage() + ' in line ' + e.getLineNumber() + ' (' + e.getStackTraceString() + ')', 'INTERNAL_ERROR');
                }

                break;
            }

            Boolean bPreventPersistence = (!Test.isRunningTest() && this.bPreventPersistence);

            if (this.oResponse.hasError() || bPreventPersistence) {

                if (!this.oResponse.hasError() && bPreventPersistence) {
                    this.oResponse.addDebug(DEBUG_HERE + 'ROLLBACK FORCED as preventPersistence is active');
                }

                if (!Test.isRunningTest()) {
                    Database.rollback(eineSchritteSuruck);
                }
            }
            else {
                this.oResponse.addDebug(DEBUG_HERE + 'Inserted opportunity ' + oOpportunity.Id);
            }

            this.oResponse.addDebug('Queries consumed: ' + Limits.getQueries() + ', left: ' + (Limits.getLimitQueries() - Limits.getQueries()));
            this.oResponse.addDebug('DMLs consumed: ' + Limits.getDmlStatements() + ', left: ' + (Limits.getLimitDmlStatements() - Limits.getDmlStatements()));
            this.oResponse.addDebug('CPU consumed: ' + (Limits.getCpuTime()/1000.0) + ' sec, left: ' + ((Limits.getLimitCpuTime() - Limits.getCpuTime())/1000.0) + ' sec');

            return this.oResponse;
        }

        /**
         * Extract ISO-3166-2 state from combined <ISO-3166-1>-<ISO-3166-2>
         *
         * @param combinendIsoCode
         *
         * @return
         */
        private String extractStateIsoCodeFromCombined(String combinendIsoCode) {

            if (combinendIsoCode == null) {
                return null;
            }

            String sExtractedIsoCode = combinendIsoCode;

            Pattern oMyPattern = Pattern.compile('^[A-Z]{2}-([A-Z]{2,3})$'); // wraps in '/<my regex>/'
            Matcher oMatcher = oMyPattern.matcher(sExtractedIsoCode);

            if (oMatcher.find()) {
                sExtractedIsoCode = oMatcher.group(1);
            }

            return sExtractedIsoCode;
        }

        /**
         * Get Products and bundled Products for SKUs recursively
         *
         * @param lsetSKUs
         * @param mapProductBySKU Filled by reference
         */
        private void getBundleProductsForSKUs(Set<String> lsetSKUs, Map<String, Product2> mapProductBySKU) {

            final String DEBUG_HERE = DEBUG_HEADER + 'getBundleProductsForSKUs() - ';

            // Query bundled Product SKUs also
            List<Product2> listProducts = new List<Product2>([
                SELECT
                    Id,
                    ProductCode,
                    Name,
                    StockKeepingUnit,
                    RecordType.DeveloperName,
                    (
                        SELECT
                            Id,
                            Pricebook2Id,
                            Pricebook2.Name,
                            UnitPrice,
                            CurrencyIsoCode
                        FROM
                            PricebookEntries
                        WHERE
                            Pricebook2.IsStandard = TRUE AND
                            CurrencyIsoCode = :THIS.sOrderCurrency
                        LIMIT 1
                    ),
                    (
                        SELECT
                            Id,
                            Definition__c,
                            IsFinallyRequired__c,
                            IsOverridesParentTargetFields__c,
                            TargetFields__c,
                            OrderInputDefinition__c,
                            OrderInputDefinition__r.Id__c,
                            OrderInputDefinition__r.InputDomain__c,
                            OrderInputDefinition__r.Validation__c,
                            OrderInputDefinition__r.ValidationValue__c,
                            OrderInputDefinition__r.AttachmentFileField__c,
                            OrderInputDefinition__r.AttachmentFileGroupId__c,
                            OrderInputDefinition__r.RecordType.DeveloperName,
                            OrderInputDefinition__r.TermsAndConditionsType__c
                        FROM
                            OrderInputDefinitionJunctions__r
                        WHERE
                            IsFinallyActive__c = TRUE
                    ),
                    (
                        SELECT
                            Id,
                            Name,
                            BundleProduct__c,
                            BundleProduct__r.StockKeepingUnit,
                            BundleProduct__r.RecordType.DeveloperName,
                            Quantity__c
                        FROM
                            BundledProducts__r
                        WHERE
                            BundleProduct__r.StockKeepingUnit != NULL AND
                            BundleProduct__r.IsActive = TRUE
                    )
                FROM
                    Product2
                WHERE
                    StockKeepingUnit IN :lsetSKUs AND
                    IsActive = TRUE
            ]);

            Set<String> lsetBundleSKUs = new Set<String>();

            for (Product2 oProduct : listProducts) {

                this.oResponse.addDebug(DEBUG_HERE + 'Add Product with SKU ' + oProduct.StockKeepingUnit + ' ("' + oProduct.Name + '"): ' + oProduct.PricebookEntries);

                mapProductBySKU.put(oProduct.StockKeepingUnit, oProduct);

                if (!oProduct.BundledProducts__r.isEmpty()) {

                    this.oResponse.addDebug(DEBUG_HERE + 'SKU has ' + oProduct.BundledProducts__r.size() + ' bundle product(s)');

                    for (ProductJunction__c oProductJunction : oProduct.BundledProducts__r) {

                        String sBundledSKU = oProductJunction.BundleProduct__r.StockKeepingUnit;

                        // Only if SKU set doesn't contain SKU already
                        if (!lsetSKUs.contains(sBundledSKU)) {
                            this.oResponse.addDebug(DEBUG_HERE + 'Found bundled SKU ' + sBundledSKU);
                            lsetBundleSKUs.add(sBundledSKU);
                        }
                    }
                }
            }

            if (!lsetBundleSKUs.isEmpty()) {
                this.getBundleProductsForSKUs(lsetBundleSKUs, mapProductBySKU);
            }
        }

        /**
         * Get OrderDefinitionValues to write all customer input according to related
         * OrderInputDefinitions of the Product which was ordered.
         * Fields are mapped via mapCustomFields.key -> OrderInputDefinition__r.Id__c.
         * OrderDefinitionValues are later related to the written OpportunityLineItems.
         *
         * @param customFieldsForDomain         Custom fields and their values which came by the product configuration for domain "product" or "checkout"
         * @param product                       Product2 corresponding to the line item
         * @param inputDomain                   Domain of the input (product or checkout)
         * @param allCustomFieldsForLineItem    All custom fields and their values which came by the product configuration
         *
         * @return
         */
        @TestVisible
        private Map<String,OrderInputDefinitionValue__c> customFieldsToOrderInputDefinitionValues(Map<String,Object> customFieldsForDomain, Product2 product, String inputDomain, Map<String,Object> allCustomFieldsForLineItem) {

            String DEBUG_HERE = DEBUG_HEADER_INNER + 'customFieldsToOrderInputDefinitionValues() - ';

            Map<String,OrderInputDefinitionValue__c> mapOrderInputDefinitionValues = new Map<String,OrderInputDefinitionValue__c>();

            if (product.OrderInputDefinitionJunctions__r.isEmpty()) {
                this.oResponse.addDebug(DEBUG_HERE+ 'No OrderInputDefinitions defined for this product');
                return mapOrderInputDefinitionValues;
            }

            Boolean bCustomFieldsForDomainSpecified = (customFieldsForDomain != null && !customFieldsForDomain.isEmpty());

            this.oResponse.addDebug(DEBUG_HERE + 'Inspect custom fields from order (domain: "' + inputDomain + '"): ' + (!bCustomFieldsForDomainSpecified ? 'none specified' : JSON.serializePretty(customFieldsForDomain)));

            if (!bCustomFieldsForDomainSpecified) {
                return mapOrderInputDefinitionValues;
            }

            for (OrderInputDefinitionJunction__c oOrderInputDefinitionJunction : product.OrderInputDefinitionJunctions__r) {

                String sCustomField     = oOrderInputDefinitionJunction.OrderInputDefinition__r.Id__c;
                String sInputDomain     = oOrderInputDefinitionJunction.OrderInputDefinition__r.InputDomain__c;
                Boolean bIsRequired     = oOrderInputDefinitionJunction.IsFinallyRequired__c;
                String sValidationType  = oOrderInputDefinitionJunction.OrderInputDefinition__r.Validation__c;
                String sValidationValue = oOrderInputDefinitionJunction.OrderInputDefinition__r.ValidationValue__c;
                String sRecordType      = oOrderInputDefinitionJunction.OrderInputDefinition__r.RecordType.DeveloperName;

                // Skip Definitions which are not applicable
                if (sInputDomain != inputDomain) {
                    continue;
                }

                if (bIsRequired) {
                    // Check constraints which come by the related OrderInputDefinition
                    // to check further conditions for a value
                    // Constraints are all "AND" linked!

                    this.oResponse.addDebug('Custom field "' + sCustomField + '" is required, check constraints if existing');

                    Id idOrderInputDefinition = oOrderInputDefinitionJunction.OrderInputDefinition__c;
                    Boolean bConstraintsFulfilled = this.oConstraintValidator.checkIfConstraintIsFulfilled(idOrderInputDefinition, allCustomFieldsForLineItem);

                    // Add debug messages
                    for (String sMessage : ConstraintValidator.debugMessages) {
                        this.oResponse.addDebug(sMessage);
                    }
                    ConstraintValidator.debugMessages.clear();

                    // So a field is only required if constraints are fulfilled
                    // otherwise field value is optional
                    bIsRequired = bIsRequired && bConstraintsFulfilled;
                }

                sValidationValue = String.isBlank(sValidationValue) ? '' : sValidationValue;

                // If the custom field of the OrderInputDefinition is not present
                // in the order then the value is set to an empty string here.
                // So the OrderInputDefinitionValue will definitely be created!
                String sCustomFieldValue = customFieldsForDomain.containsKey(sCustomField) ? ConstraintValidator.forceEmptyStringOnNull(String.valueOf(customFieldsForDomain.get(sCustomField))).trim() : '';

                if (!customFieldsForDomain.containsKey(sCustomField)) {
                    this.oResponse.addDebug('Field "' + sCustomField + '" is not present in the custom fields of the order (' + inputDomain + ') and will forced to be empty');
                }

                // Check if value is required
                if (bIsRequired && sCustomFieldValue.length() == 0) {
                    this.oResponse.setFieldValidationError('"' + sCustomField + '" is required', sCustomField);
                    return null;
                }

                // Initialize new Order Input Definition Value
                OrderInputDefinitionValue__c oOrderInputDefinitionValue = new OrderInputDefinitionValue__c(
                    OrderInputDefinition__c = oOrderInputDefinitionJunction.OrderInputDefinition__c,
                    OrderInputDefinitionJunction__c = oOrderInputDefinitionJunction.Id
                );

                // Special handling of fields which are sub objects
                if (sRecordType == 'price') {
                    // e.g.
                    // {
                    //      "fractionDigits": 2,
                    //      "centAmount": 9212,
                    //      "currencyCode": "EUR",
                    //      "type": "centPrecision"
                    // }
                    Map<String,Object> mapPrice = (Map<String,Object>)customFieldsForDomain.get(sCustomField);

                    if (mapPrice != null) {

                        if (mapPrice.get('centAmount') == null) {
                            this.oResponse.setFieldValidationError('"centAmount" for price "' + sCustomField + '" not found', sCustomField);
                            return null;
                        }

                        try {
                            sCustomFieldValue = String.valueOf(Double.valueOf(mapPrice.get('centAmount'))/100);
                        }
                        catch (Exception e) {
                            this.oResponse.setFieldValidationError('Invalid price value for "centAmount"', sCustomField);
                            return null;
                        }
                    }
                }
                else if (sRecordType == 'attachment') {

                    String sAttachmentFileField    = oOrderInputDefinitionJunction.OrderInputDefinition__r.AttachmentFileField__c;
                    String sAttachmentFileGroupdId = oOrderInputDefinitionJunction.OrderInputDefinition__r.AttachmentFileGroupId__c;

                    if (!this.mapAttachments.containsKey(sAttachmentFileGroupdId)) {
                        this.mapAttachments.put(sAttachmentFileGroupdId, new Map<String,String>());
                    }

                    this.mapAttachments.get(sAttachmentFileGroupdId).put(sAttachmentFileField, sCustomFieldValue);
                }
                // since 2018-06-13 (SOBCRM-1189)
                else if (sRecordType == 'termsAndConditions') {

                    // Get the Terms and Condition type from Order Input Definition
                    String sTermsAndConditionsType = oOrderInputDefinitionJunction.OrderInputDefinition__r.TermsAndConditionsType__c;
                    String sCountryIsoCode         = oOpportunity.ShippingCountryIsoCode__c;
                    String sLanguageIsoCode        = oOpportunity.Language__c;

                    if (String.isEmpty(sCountryIsoCode)) {
                        this.oResponse.setFieldValidationError('Country not defined', 'country');
                        return null;
                    }

                    if (String.isEmpty(sLanguageIsoCode)) {
                        this.oResponse.setFieldValidationError('Language not defined', 'language');
                        return null;
                    }

                    // Get the latest Terms and Conditions for the configured type (Global value set of TermsAndConditions object).
                    // We assume that the latest active version presented to the customer hasn't change during checkout and order!
                    // Since SOBCRM-1260 also Language Code and Country Code are required.
                    List<TermsAndConditions__c> listTermsAndConditions = [
                        SELECT
                            Id, Name
                        FROM
                            TermsAndConditions__c
                        WHERE
                            Type__c = :sTermsAndConditionsType AND
                            Country__c = :sCountryIsoCode AND
                            Language__c = :sLanguageIsoCode AND
                            Current__c = TRUE
                    ];

                    if (listTermsAndConditions.size() == 1) {

                        TermsAndConditions__c oTermsAndConditions = listTermsAndConditions.get(0);
                        oOrderInputDefinitionValue.TermsAndConditions__c = oTermsAndConditions.Id;

                        this.oResponse.addDebug(DEBUG_HERE +
                            'Found Terms and Conditions object "' + oTermsAndConditions.Name + '" ' +
                            '(' + oTermsAndConditions.Id + ') for type "' + sTermsAndConditionsType + '" and related it ' +
                            'to new Order Input Definition Value'
                        );
                    }
                    else {

                        String sNote = '';

                        if (listTermsAndConditions.isEmpty()) {
                            sNote = 'No Terms and Conditions marked as current found for type "' + sTermsAndConditionsType + '"';
                        }
                        else {
                            sNote = 'No unique Terms and Conditions marked as current found for type "' + sTermsAndConditionsType + '"';
                        }

                        oOrderInputDefinitionValue.TermsAndConditionsTypeNote__c = sNote;
                        this.oResponse.addDebug(DEBUG_HERE + sNote);
                    }
                }
                // IF a value is set and a validation is configured run check
                else if (sCustomFieldValue.length() > 0) {

                    // Check on validation
                    if (sValidationType == 'integer' && !Pattern.matches('-?[0-9]+', sCustomFieldValue)) { // wrapped in '/^<my regex>$/' automatically
                        this.oResponse.setFieldValidationError('Value should be an integer', sCustomField);
                        return null;
                    }
                    else if (sValidationType == 'float' && !Pattern.matches('-?[0-9]+(\\.[0-9]+)?', sCustomFieldValue)) {
                        this.oResponse.setFieldValidationError('Value should be float', sCustomField);
                        return null;
                    }
                    else if (sValidationType == 'email' && !Pattern.matches('[^@]+@[^@]{2,}\\.[^@]{2,}', sCustomFieldValue)) {
                        this.oResponse.setFieldValidationError('Value should be an email', sCustomField);
                        return null;
                    }
                    else if (sValidationType == 'regex' && !Pattern.matches(sValidationValue, sCustomFieldValue)) {
                        this.oResponse.setFieldValidationError('Value should match regular expression', sCustomField);
                        return null;
                    }
                }

                this.oResponse.addDebug(DEBUG_HERE + 'Value for custom field "' + sCustomField + '" of type "' + sRecordType + '": ' + sCustomFieldValue);

                // If not required, empty values are allowed!
                oOrderInputDefinitionValue.Value__c = sCustomFieldValue;
                mapOrderInputDefinitionValues.put(sCustomField, oOrderInputDefinitionValue);
            }

            return mapOrderInputDefinitionValues;
        }
    }

    /**
     * Saves an attachment by URL and links it to a specified SObject
     *
     * Has to be declared here as inner class methods cannot be declared static.
     *
     * Please notice to add sites under Remote Site Settings!
     *
     * @param attachmentURL
     * @param attachmentName
     * @param idLinkedObject
     * @since v1.7.0 (2018-05-09)
     */
    @future(callout=true)
    global static void saveAttachmentToObject(String attachmentURL, String attachmentName, Id idLinkedObject) {

        String DEBUG_HERE = DEBUG_HEADER + 'saveAttachmentToObject() - ';

        // Set mock in test mode
        if (Test.isRunningTest() == true) {
            // Todo
            Test.setMock(HttpCalloutMock.class, new RESTServiceOrder.AttachmentLoaderMockDispatcher());
        }

        if (String.isBlank(attachmentURL)) {
            System.debug(DEBUG_HERE + 'No attachmentURL defined');
            return;
        }

        attachmentURL = attachmentURL.replace(' ', '%20');

        HttpRequest request = new HttpRequest();
        request.setEndpoint(attachmentURL);
        request.setMethod('GET');
        request.setTimeout(6000);

        Http http = new Http();

        if (String.isBlank(attachmentName)) {
            attachmentName = attachmentURL.substring(attachmentURL.lastIndexOf('/')+1);
            System.debug(DEBUG_HERE + 'Missing name - extracting basename from URL: ' + attachmentName);
        }

        System.debug(DEBUG_HERE + 'Fetch file "' + attachmentName + '" at ' + attachmentURL);

        try {

            HttpResponse response = http.send(request);
            Blob attachmentBlob = response.getBodyAsBlob();

            System.debug(DEBUG_HERE + 'Response: ' + response);
            System.debug(DEBUG_HERE + 'Attachment size: ' + attachmentBlob.size() + ' bytes');

            ContentVersion oContentVersion = new ContentVersion(
                ContentLocation = 'S', // located in Salesforce
                Title           = attachmentName,
                VersionData     = attachmentBlob,
                PathOnClient    = attachmentURL,
                Description     = 'Source URL: ' + attachmentURL
            );
            insert oContentVersion;

            // Get ContentDocumentId from created ContentVersion object
            oContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :oContentVersion.Id];

            insert new ContentDocumentLink(
                ContentDocumentId = oContentVersion.ContentDocumentId,
                LinkedEntityId    = idLinkedObject,
                ShareType         = 'I'
            );

            System.debug(
                DEBUG_HERE + 'Inserted new File (ContentDocument) "' + oContentVersion.ContentDocumentId + '" created automatically by ' +
                'new ContentVersion "' + oContentVersion.Id + '" and linked it to SObject "' + idLinkedObject + '"'
            );

            /*
            if (attachmentBlob != NULL) {
                Attachment attachment = new Attachment(
                    Name        = attachmentName,
                    Body        = attachmentBlob,
                    ParentId    = idLinkedObject,
                    Description = 'Source-URL: ' + attachmentURL
                );
                insert attachment;

                System.debug(DEBUG_HEADER + 'Insert Attachment: ' + attachment);
            }
            */
        }
        catch (Exception e) {

            System.debug(DEBUG_HERE + 'Exception: ' + e);

            Case errorCase = new Case();
            errorCase.Subject = 'Error on downloading attachment';
            errorCase.Description  = e.getMessage() + (e.getCause() != NULL ? ' ' + e.getCause() : '')  + (e.getLineNumber() > 0 ? ' in line #' + e.getLineNumber() : '') + '\n\n';
            errorCase.Description += 'Attachment Name: ' + attachmentName + '\n';
            errorCase.Description += 'Attachment URL: ' + attachmentURL + '\n';
            errorCase.Description += 'SObject ID: ' + idLinkedObject + '\n';
            insert errorCase;
        }
    }

    /**
     * Response
     *
     * Special inner response class for this endpoint
     */
    global class Response {

        public Map<String,String> error = new Map<String,String>();
        public List<String> debug = new List<String>();
        public Map<String,List<SObject>> objects = new Map<String,List<SObject>>();

        /**
         * Add a list of SObjects
         *
         * @param name
         * @param listSObjects
         */
        public void addObjects(String name, List<SObject> listSObjects) {

            if (!this.objects.containsKey(name)) {
                this.objects.put(name, new List<SObject>());
            }

            this.objects.get(name).addAll(listSObjects);
        }

        /**
         * Add an SObject
         *
         * @param name
         * @param oSObject
         */
        public void addObject(String name, SObject oSObject) {
            this.addObjects(name, new List<SObject>{oSObject});
        }

        /**
         * Set the error
         *
         * Default status code is set to 500
         *
         * @param error
         * @param code
         */
        public void setError(String error, String code) {
            this.setError(error, code, 500);
        }

        /**
         * Set the error with additional status code
         *
         * @param error
         * @param code
         * @param httpStatusCode
         */
        public void setError(String error, String code, Integer httpStatusCode) {
            this.error.put('message', error);
            this.error.put('code', code);
            if (this.error.containsKey('field')) {
                this.error.remove('field');
            }
            RestContext.response.statusCode = httpStatusCode;
        }

        /**
         * Set a field validation error
         *
         * @param error
         * @param fieldName
         */
        public void setFieldValidationError(String error, String fieldName) {
            this.error.put('message', error);
            this.error.put('field', fieldName);
            this.error.put('code', 'VALIDATION_ERROR');
            RestContext.response.statusCode = 400;
        }

        /**
         * Returns if an error exists
         *
         * @return
         */
        public Boolean hasError() {
            return !error.isEmpty();
        }

        /**
         * Add a debug information
         *
         * @param debugMessage
         */
        public void addDebug(String debugMessage) {
            this.debug.add(System.now().format('yyyy-MM-dd HH:mm:ss') + '.' + System.now().millisecond() + ' - ' + debugMessage);
            if (!suppressDebug) System.debug('RESTServiceOrder.Response - ' + debugMessage);
        }
    }

    /**
     * Mock class for callout method saveAttachmentToObject()
     *
     * @see saveAttachmentToObject()
     */
    public class AttachmentLoaderMockDispatcher implements HttpCalloutMock {

        public final String RESPONSE_BODY = 'Filecontent :P';

        /**
         * Implemented method from interface as route dispatcher
         */
        public HttpResponse respond(HttpRequest request) {

            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/pdf');

            response.setBody(RESPONSE_BODY);
            response.setStatusCode(200);

            return response;
        }
    }
}