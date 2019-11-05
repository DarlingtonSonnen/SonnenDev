/**
 * Tests for RESTService, WebOrderContractCreator classes
 *
 * Changelog
 * ---------
 * v1.0.0   2018-02-12  Marko Schmalenbach          Initial version
 * v1.1.0   2018-03-26  Polina Tsuban-Drobot        Covered functionality of WebOrderContractCreator (SOBCRM-1167)
 * v1.2.0   2018-04-26  Polina Tsuban-Drobot        Removed checking for WebOrderContractCreator: functionality transferred to ContractCreatorFromOpportunity component (SOBCRM-1163)
 * v1.3.0   2018-05-09  Marko Schmalenbach          Added tests on created attachment files on Opportunity (SOBCRM-1169)
 * v1.4.0   2018-06-15  Marko Schmalenbach          Added tests for checking setting of TermsAndCondition ID on OrderInputDefinitionValue of type "termsAndConditions" (SOBCRM-1189)
 * v1.5.0   2018-06-19  Marko Schmalenbach          Added test for attachment with missing name
 * v1.6.0   2018-07-03  Marko Schmalenbach          Added Order Input Definition with target field on Meter Installation (SOBCRM-1154)
 * v1.7.0   2018-09-19  Marko Schmalenbach          - Added Language and Country for Terms and Conditions (SOBCRM-1260)
 *                                                  - Changed TERMS_AND_CONDITION_TYPE to a new picklist value
 * v1.8.0   2018-10-12  Marko Schmalenbach          Extended tests to test Bundles with Hardware products and Subsidy (especially for Australia) (SOBCRM-1256, SOBCRM-1271)
 * v1.9.0   2018-10-16  Marko Schmalenbach          Extended tests to test (SOBCRM-1271):
 *                                                  - Opportunity.WebOrderTotalPrice__c
 *                                                  - OpportunityLineItem.WebOrderUnitPrice__c
 *                                                  - OpportunityLineItem.WebOrderTotalPrice__c
 * v1.9.1   2018-10-17  Marko Schmalenbach          setAustralianSubsidyAmount(): OpportunityLineItem for Subsidy respects now added tax rate
 * v1.9.2   2018-10-18  Marko Schmalenbach          More tests on address information due to change in RESTServiceOrder v2.2.0
 * v1.9.3   2018-10-24  Marko Schmalenbach          Added test of ShippingPhone__c
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @since 2018-02-12
 * @see RESTServiceOrder
 */
@IsTest (SeeAllData=false)
public class RESTServiceOrder_Test {

    private static Map<String, Product2> mapProducts = new Map<String, Product2>();

    public static Map<String,Object> requestDataRESTServiceOrder = new Map<String,Object>();
    public static Map<String,Object> requestDataRESTServiceOrderBundleAU = new Map<String,Object>();

    private static Map<Id,OrderInputDefinition__c> mapOrderInputDefinitionsById = new Map<Id,OrderInputDefinition__c>();
    private static Map<String,OrderInputDefinition__c> mapOrderInputDefinitionsByFieldId = new Map<String,OrderInputDefinition__c>();

    private static String DEBUG_HEADER = 'RESTServiceOrder_Test.';

    private static final String TERMS_AND_CONDITION_TYPE     = 'Privacy Policy';
    private static final String TERMS_AND_CONDITION_LANGUAGE = 'de'; // since SOBCRM-1260
    private static final String TERMS_AND_CONDITION_COUNTRY  = 'DE'; // since SOBCRM-1260

    private static final String AUSTRALIA_CURRENCY_CODE = 'AUD';
    private static final String AUSTRALIA_COUNTRY_CODE = 'AU';
    private static final String AUSTRALIA_LANGUAGE_CODE = 'de';

    private static Map<String, String> mapAustralianSubsidySettings = new Map<String, String>();
    private static Map<String, PricebookEntry> mapPricebookEntries = new Map<String, PricebookEntry>();

    /**
     * Setup static
     */
    @IsTest
    public static void setupStatic() {

        //---------------------------------
        // Check Australia Settings
        //---------------------------------
        // Important to calculate Subsidy amount!
        for (AustraliaSetting__mdt oAustraliaSetting : [SELECT Id, DeveloperName, TextValue__c FROM AustraliaSetting__mdt]) {
            mapAustralianSubsidySettings.put(oAustraliaSetting.DeveloperName, oAustraliaSetting.TextValue__c);
        }

        System.assert(mapAustralianSubsidySettings.containsKey('SubsidyMaxAmount'), 'Expected AustraliaSetting__mdt for "SubsidyMaxAmount"');
        System.assert(mapAustralianSubsidySettings.containsKey('SubsidyWithConcessionFactorAmount'), 'Expected AustraliaSetting__mdt for "SubsidyWithConcessionFactorAmount"');
        System.assert(mapAustralianSubsidySettings.containsKey('SubsidyWithoutConcessionFactorAmount'), 'Expected AustraliaSetting__mdt for "SubsidyWithoutConcessionFactorAmount"');

        //---------------------------------
        // Create products
        //---------------------------------
        Id idPricebook = Test.getStandardPricebookId();
        String sCurrentRecordTypeName;

        // eService (master/main) product
        sCurrentRecordTypeName = 'eService';
        mapProducts.put(sCurrentRecordTypeName, new Product2(
            Name = 'sonnenFlat 5500',
            RecordTypeId = DiaUtilities.getRecordTypeId('Product2', sCurrentRecordTypeName),
            StockKeepingUnit = 'es-rc-sonnenFlat-home-5500-v3.0-de-UNITTEST', // Must be unique though SeeAllData is false
            ContractRecordType__c = 'SonnenFlat',
            ContractTariffType__c = 'SonnenFlat',
            ContractType__c = 'sonnenbatterieHome-DE',
            IsActive = true
        ));

        // eService bundle product
        sCurrentRecordTypeName = 'eServiceBundleProduct';
        mapProducts.put(sCurrentRecordTypeName, new Product2(
            Name = 'sonnenCommunity Flat',
            RecordTypeId = DiaUtilities.getRecordTypeId('Product2', sCurrentRecordTypeName),
            StockKeepingUnit = 'es-rc-sonnenCommunity-flat-de-UNITTEST',
            ContractRecordType__c = 'SonnenFlat',
            ContractTariffType__c = 'SonnenFlat',
            ContractType__c = 'sonnenbatterieHome-DE',
            IsActive = true
        ));

        // Since 2018-10-12
        // Financing/Payment
        sCurrentRecordTypeName = 'Payment';
        mapProducts.put(sCurrentRecordTypeName, new Product2(
            Name = 'Financing',
            RecordTypeId = DiaUtilities.getRecordTypeId('Product2', sCurrentRecordTypeName),
            StockKeepingUnit = 'financing-UNITTEST',
            IsActive = true
        ));

        // Hardware
        sCurrentRecordTypeName = 'Standard';
        mapProducts.put(sCurrentRecordTypeName, new Product2(
            Name = 'sonnen Battery',
            RecordTypeId = DiaUtilities.getRecordTypeId('Product2', 'Standard'),
            StockKeepingUnit = 'sonnenBattery-UNITTEST',
            IsActive = true
        ));

        // Service
        sCurrentRecordTypeName = 'Service';
        mapProducts.put(sCurrentRecordTypeName, new Product2(
            Name = 'Battery Installation',
            RecordTypeId = DiaUtilities.getRecordTypeId('Product2', 'Service'),
            StockKeepingUnit = 'battery-installation-UNITTEST',
            IsActive = true
        ));

        // Subsidy (especially for Australia)
        sCurrentRecordTypeName = 'Subsidy';
        mapProducts.put(sCurrentRecordTypeName, new Product2(
            Name = 'Subsidy',
            RecordTypeId = DiaUtilities.getRecordTypeId('Product2', 'Subsidy'),
            StockKeepingUnit = 'subsidy-UNITTEST',
            IsActive = true
        ));

        // General Bundle (bundles Hardware and eService)
        sCurrentRecordTypeName = 'Bundle';
        mapProducts.put(sCurrentRecordTypeName, new Product2(
            Name = 'Bundle Product',
            RecordTypeId = DiaUtilities.getRecordTypeId('Product2', 'Bundle'),
            StockKeepingUnit = 'bundle-UNITTEST',
            IsActive = true
        ));

        insert mapProducts.values();

        //-------------------
        // Bundles
        //-------------------
        List<ProductJunction__c> listProductJunctions = new List<ProductJunction__c>();

        Product2 oBundleProduct = mapProducts.get('Bundle');

        for (String sProductRecordTypeName : new List<String>{'Payment', 'Standard', 'Service', 'Subsidy'}) {

            listProductJunctions.add(new ProductJunction__c(
                MasterProduct__c = oBundleProduct.Id,
                BundleProduct__c = mapProducts.get(sProductRecordTypeName).Id,
                Quantity__c = 1
            ));
        }

        //---------------------------------
        // Bundle eService Products
        //---------------------------------
        listProductJunctions.add(new ProductJunction__c(
            MasterProduct__c = mapProducts.get('eService').Id,
            BundleProduct__c = mapProducts.get('eServiceBundleProduct').Id,
            Quantity__c = 1
        ));

        insert listProductJunctions;

        //---------------------------------
        // Update standard Pricebook
        //---------------------------------
        Pricebook2 oPricebook = new Pricebook2(
            Id = idPricebook,
            IsActive = true
        );
        update oPricebook;

        //---------------------------------
        // Create PricebookEntries
        //---------------------------------
        List<String> listCurrencies = new List<String>{
            RESTServiceOrder.DEFAULT_CURRENCY_CODE,
            AUSTRALIA_CURRENCY_CODE
        };

        for (Product2 oProduct2 : mapProducts.values()) {

            Decimal fUnitPrice = 0.00;

            switch on oProduct2.StockKeepingUnit {
                when 'sonnenBattery-UNITTEST' {
                    fUnitPrice = 12569.00;
                }
                when 'battery-installation-UNITTEST' {
                    fUnitPrice = 1299.00;
                }
            }

            for (String sCurrencyCode : listCurrencies) {
                mapPricebookEntries.put(sCurrencyCode + '-' + oProduct2.StockKeepingUnit, new PricebookEntry(
                    IsActive        = true,
                    Pricebook2Id    = idPricebook,
                    Product2Id      = oProduct2.Id,
                    UnitPrice       = fUnitPrice,
                    CurrencyIsoCode = sCurrencyCode
                ));
            }
        }

        insert mapPricebookEntries.values();

        //---------------------------------
        // Create OrderInputDefinitions
        //---------------------------------
        List<OrderInputDefinition__c> listOrderInputDefinitions = new List<OrderInputDefinition__c>{
            new OrderInputDefinition__c(
                Id__c = 'cPVSize__c',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'text'),
                Label__c = 'PV Größe (kWp)',
                InputDomain__c = 'Product',
                TargetField__c = 'Contract.PVSize__c',
                // Attention: Dependency to ContractCreatorFromOpportunityCtrlTest!
                TargetFields__c = WebOrderContractCreator.PV_PLANT_ASSET_RECORD_TYPE + '.PVSizekWp__c',
                Validation__c = 'float',
                IsRequired__c = false
            ),
            new OrderInputDefinition__c(
                Id__c = 'cConsumptionEstimated',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'text'),
                Label__c = 'Geschätzter Jahresverbrauch (kWh)',
                InputDomain__c = 'Product',
                TargetField__c = 'Contract.AnnualConsumption__c',
                Validation__c = 'integer',
                IsRequired__c = true
            ),
            new OrderInputDefinition__c(
                Id__c = 'cProviderChangeReason',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'selectRadioCheckbox'),
                Label__c = 'Wechselgrund',
                InputDomain__c = 'Checkout',
                TargetField__c = 'Contract.SubscriptionReason__c',
                IsRequired__c = false
            ),
            new OrderInputDefinition__c(
                Id__c = 'cBatteryNumber',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'selectRadioCheckbox'),
                Label__c = 'Batterie Seriennummer',
                InputDomain__c = 'Checkout',
                TargetField__c = 'Contract.BatterySerialNumber__c',
                Validation__c = 'regex',
                ValidationValue__c = 'SER-[0-9]{10}',
                IsRequired__c = true
            ),
            new OrderInputDefinition__c(
                Id__c = 'cProviderPreviousName',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'text'),
                Label__c = 'Vorheriger Anbieter',
                InputDomain__c = 'Checkout',
                TargetField__c = 'Contract.PreviousProviderName__c',
                // Not required per standard but will be overwritten by junction beneath!
                IsRequired__c = false
            ),
            new OrderInputDefinition__c(
                Id__c = 'cBatterySize',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'text'),
                Label__c = 'Batteriegröße',
                InputDomain__c = 'Product',
                Validation__c = 'float',
                TargetField__c = 'Contract.CapacitySonnenBattery__c',
                IsRequired__c = true
            ),
            new OrderInputDefinition__c(
                Id__c = 'cAttachment1URL',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'attachment'),
                Label__c = '1. Datei hochladen',
                AttachmentFileGroupId__c = '1', // picklist!
                AttachmentFileField__c = 'URL', // picklist!
                InputDomain__c = 'Product',
                IsRequired__c = false
            ),
            new OrderInputDefinition__c(
                Id__c = 'cAttachment1Name',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'attachment'),
                Label__c = 'Name der Datei',
                AttachmentFileGroupId__c = '1', // picklist!
                AttachmentFileField__c = 'name', // picklist!
                InputDomain__c = 'Product',
                IsRequired__c = false
            ),
            // Test attachment without corresponding name
            new OrderInputDefinition__c(
                Id__c = 'cAttachment2URL',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'attachment'),
                Label__c = '2. Datei hochladen',
                AttachmentFileGroupId__c = '2', // picklist!
                AttachmentFileField__c = 'URL', // picklist!
                InputDomain__c = 'Product',
                IsRequired__c = false
            ),
            new OrderInputDefinition__c(
                Id__c = 'RegularPrePayment',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'price'),
                Label__c = 'Vorauszahlung',
                InputDomain__c = 'Product',
                TargetField__c = 'Contract.RegularPrePayment__c',
                IsRequired__c = false
            ),
            new OrderInputDefinition__c(
                Id__c = 'cTermsAndConditionSonnen',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'termsAndConditions'),
                Label__c = 'AGB Sonnen Stromtarif',
                InputDomain__c = 'Checkout',
                TargetField__c = 'Contract.TermsOfServiceConfirmed__c',
                IsRequired__c = true,
                TermsAndConditionsType__c = TERMS_AND_CONDITION_TYPE // Global Picklist value! Should be configured
            ),
            new OrderInputDefinition__c(
                Id__c = 'cMeterId',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'text'),
                Label__c = 'Zählernummer',
                InputDomain__c = 'Product',
                TargetField__c = 'Contract.MeterId__c',
                // Attention: Dependency to ContractCreatorFromOpportunityCtrlTest!
                TargetFields__c = 'MeterInstallation__c.ProductionMeterID__c',
                IsRequired__c = true
            ),
            new OrderInputDefinition__c(
                Id__c = 'cBirthdate',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'date'),
                Label__c = 'Geburtstag',
                InputDomain__c = 'Checkout',
                TargetField__c = 'Contact.Birthdate'
            ),
            new OrderInputDefinition__c(
                Id__c = 'cUpfrontPayment',
                RecordTypeId = DiaUtilities.getRecordTypeId('OrderInputDefinition__c', 'price'),
                Label__c = 'Anzahlung',
                InputDomain__c = 'Product',
                TargetField__c = 'OpportunityLineItem.UnitPrice',
                IsRequired__c = false
            )
        };

        insert listOrderInputDefinitions;

        for (OrderInputDefinition__c oOrderInputDefinition : listOrderInputDefinitions) {
            mapOrderInputDefinitionsById.put(oOrderInputDefinition.Id, oOrderInputDefinition);
            mapOrderInputDefinitionsByFieldId.put(oOrderInputDefinition.Id__c, oOrderInputDefinition);
        }

        //---------------------------------
        // Create Terms and Conditions
        //---------------------------------
        insert new TermsAndConditions__c(
            Name        = 'Terms Sonnen',
            Type__c     = TERMS_AND_CONDITION_TYPE,
            Country__c  = TERMS_AND_CONDITION_COUNTRY,  // since SOBCRM-1260
            Language__c = TERMS_AND_CONDITION_LANGUAGE, // since SOBCRM-1260
            Current__c  = true
        );

        //---------------------------------
        // Create Definition Junctions
        //---------------------------------

        // eService Order
        List<OrderInputDefinitionJunction__c> listDefinitionJunctions = new List<OrderInputDefinitionJunction__c>();

        for (OrderInputDefinition__c oOrderInputDefinition : listOrderInputDefinitions) {

            if (oOrderInputDefinition.Id__c == 'cUpfrontPayment') {
                continue;
            }

            OrderInputDefinitionJunction__c oOrderInputDefinitionJunction = new OrderInputDefinitionJunction__c(
                OrderInputDefinition__c = oOrderInputDefinition.Id,
                Product__c = mapProducts.get('eService').Id,
                IsActive__c = true
            );

            // Field normally is not required but this can be overwritten
            // by the junction and in combination with a constraint beneath
            // this requirement is mandatory.
            if (oOrderInputDefinition.Id__c == 'cProviderPreviousName') {
                oOrderInputDefinitionJunction.IsRequired__c = true;
                oOrderInputDefinitionJunction.IsOverridesParentRequirement__c = true;
            }

            listDefinitionJunctions.add(oOrderInputDefinitionJunction);
        }

        // Bundle (Hardware, so far ... will be changing)

        // Battery Size
        listDefinitionJunctions.add(new OrderInputDefinitionJunction__c(
            OrderInputDefinition__c = mapOrderInputDefinitionsByFieldId.get('cBatterySize').Id,
            Product__c = mapProducts.get('Bundle').Id,
            // Important for Australian Subsidy calculation! (Todo: solve this with other Trigger logic 🤔)
            TargetFields__c = 'Opportunity.BatteryCapacity__c',
            IsOverridesParentTargetFields__c = true,
            IsActive__c = true
        ));

        // Upfront Payment
        listDefinitionJunctions.add(new OrderInputDefinitionJunction__c(
            OrderInputDefinition__c = mapOrderInputDefinitionsByFieldId.get('cUpfrontPayment').Id,
            Product__c = mapProducts.get('Payment').Id,
            IsActive__c = true
        ));

        insert listDefinitionJunctions;

        //---------------------------------
        // Create eService order
        //---------------------------------
        // This will be changed in the future!
        requestDataRESTServiceOrder = new Map<String,Object>{
            'lineItems' => new List<Object>{
                // eService product
                new Map<String,Object>{
                    'variant' => new Map<String,Object>{
                        'sku' => mapProducts.get('eService').StockKeepingUnit
                    },
                    'totalPrice' => new Map<String,Object>{
                        'centAmount' => 1999
                    },
                    'quantity' => 1,
                    // Custom PRODUCT fields
                    'custom' => new Map<String,Object>{
                        'fields' => new Map<String,Object>{
                            'cPVSize__c'            => 12.5,
                            'cMeterId'              => 123456789,
                            'cConsumptionEstimated' => 2500,
                            'cBatterySize'          => 8,
                            'cAttachment1URL'       => 'https://test.de/testdatei.pdf',
                            'cAttachment1Name'      => 'testdatei.pdf',
                            'cAttachment2URL'       => 'https://test.de/testdatei2.pdf', // without name
                            'RegularPrePayment'     => new Map<String,Object>{
                                'fractionDigits' => 2,
                                'centAmount'     => 9212,
                                'currencyCode'   => 'EUR',
                                'type'           => 'centPrecision'
                            }
                        }
                    }
                },
                // eService Bundle product
                new Map<String,Object>{
                    'variant' => new Map<String,Object>{
                        'sku' => mapProducts.get('eServiceBundleProduct').StockKeepingUnit
                    },
                    'totalPrice' => new Map<String,Object>{
                        'centAmount' => 999
                    },
                    'quantity' => 1
                }
            },
            // Custom CHECKOUT fields
            'custom' => new Map<String,Object>{
                'fields' => new Map<String,Object>{
                    'cBirthdate'                => '2015-12-19',
                    'cProviderChangeReason'     => 'Change of Provider (E03)',
                    'cProviderPreviousName'     => 'Hans Wurst AG',
                    'cBatteryNumber'            => 'SER-1234567890',
                    'cTermsAndConditionSonnen'  => 'true'
                }
            },
            'billingAddress' => new Map<String,Object>{
                'salutation'    => 'Mr.',
                'firstName'     => 'Walter',
                'lastName'      => 'Schmidt',
                'streetName'    => 'Meine Strasse',
                'streetNumber'  => '5',
                'postalCode'    => '22111',
                'city'          => 'Hamburg',
                'country'       => 'DE',
                'additionalStreetInfo' => 'Ecke EDEKA',
                'state'         => 'MV'
            },
            'shippingAddress' => new Map<String,Object>{
                'salutation'    => 'Ms.',
                'firstName'     => 'Franka',
                'lastName'      => 'Potente',
                'streetName'    => 'Hofweg',
                'streetNumber'  => '2',
                'postalCode'    => '10000',
                'city'          => 'Irgendwo',
                'country'       => 'DE',
                'email'         => 'test@test.de',
                'phone'         => '0123-456789',
                'additionalStreetInfo' => 'Ecke EDEKA',
                'state'         => 'MV'
            }
        };

        //---------------------------------
        // Create bundle order (AU)
        //---------------------------------
        requestDataRESTServiceOrderBundleAU = new Map<String,Object>{
            'locale' => AUSTRALIA_LANGUAGE_CODE,
            'country' => AUSTRALIA_COUNTRY_CODE,
            'totalPrice' => new Map<String,Object>{
                'currencyCode' => AUSTRALIA_CURRENCY_CODE,
                'centAmount'    => 2011100
            },
            'lineItems' => new List<Object>{
                // Bundle product
                new Map<String,Object>{
                    'variant' => new Map<String,Object>{
                        'sku' => mapProducts.get('Bundle').StockKeepingUnit
                    },
                    'price' => new Map<String,Object>{
                        'value' => new Map<String,Object>{
                            'centAmount' => 1599900
                        }
                    },
                    'totalPrice' => new Map<String,Object>{
                        'centAmount' => 1899900
                    },
                    'quantity' => 1,
                    // Custom PRODUCT fields
                    'custom' => new Map<String,Object>{
                        'fields' => new Map<String,Object>{
                            'cBatterySize' => 123456.78 // insane size!
                        }
                    }
                }
            },
            'customLineItems' => new List<Object>{
                // Financing
                new Map<String,Object>{
                    'slug' => mapProducts.get('Payment').StockKeepingUnit,
                    'quantity' => 1,
                    // Custom PRODUCT fields
                    'custom' => new Map<String,Object>{
                        'fields' => new Map<String,Object>{
                            'cPayType' => 'PartFinancing',
                            'cUpfrontPayment'     => new Map<String,Object>{
                                'fractionDigits' => 2,
                                'centAmount'     => 2000 * 100,
                                'currencyCode'   => AUSTRALIA_CURRENCY_CODE,
                                'type'           => 'centPrecision'
                            }
                        }
                    }
                }
            },
            // Custom CHECKOUT fields
            'custom' => new Map<String,Object>{
                'fields' => new Map<String,Object>{
                    'cBirthdate' => '2015-12-19'
                }
            },
            'billingAddress' => new Map<String,Object>{
                'salutation'    => 'Mr.',
                'firstName'     => 'John',
                'lastName'      => 'Mate',
                'streetName'    => 'Flushcombe Road',
                'streetNumber'  => '100',
                'postalCode'    => '2148',
                'city'          => 'Blacktown',
                'country'       => AUSTRALIA_COUNTRY_CODE,
                'additionalStreetInfo' => 'APT 15',
                'state'         => 'SA',
                'phone'         => '0123-456789',
                'email'         => 'mate@australia.test1'
            },
            'shippingAddress' => new Map<String,Object>{
                'salutation'    => 'Mr.',
                'firstName'     => 'John',
                'lastName'      => 'Mate',
                'streetName'    => 'Flushcombe Road',
                'streetNumber'  => '100',
                'postalCode'    => '2148',
                'city'          => 'Blacktown',
                'country'       => AUSTRALIA_COUNTRY_CODE,
                'additionalStreetInfo' => 'APT 15',
                'state'         => 'SA',
                'phone'         => '9876-543210',
                'email'         => 'mate@australia.test2'
            }
        };

        //---------------------------------
        // Create Constraints and Groups
        //---------------------------------
        List<Constraint__c> listConstraints = new List<Constraint__c>{
            new Constraint__c(
                ReferencedField__c      = 'cProviderChangeReason',
                Operator__c             = '==',
                ValueToMatch__c         = 'Change of Provider (E03)',
                Type__c                 = 'String',
                OrderInputDefinition__c = mapOrderInputDefinitionsByFieldId.get('cProviderPreviousName').Id
            ),
            new Constraint__c(
                ReferencedField__c      = 'cPVSize__c',
                Operator__c             = '>',
                ValueToMatch__c         = '10.3',
                Type__c                 = 'Number',
                OrderInputDefinition__c = mapOrderInputDefinitionsByFieldId.get('cProviderPreviousName').Id
            )
        };
        insert listConstraints;

        // Add a Constraint Group with OR linked Constraints
        // so we get: A AND B AND (C OR D)
        ConstraintGroup__c oConstraintGroup = new ConstraintGroup__c(
            Operator__c = 'OR',
            OrderCheckoutDefinition__c = mapOrderInputDefinitionsByFieldId.get('cProviderPreviousName').Id
        );
        insert oConstraintGroup;

        listConstraints = new List<Constraint__c>{
            new Constraint__c(
                ReferencedField__c      = 'cConsumptionEstimated',
                Operator__c             = '<=',
                ValueToMatch__c         = '2500',
                Type__c                 = 'Number',
                ConstraintGroup__c      = oConstraintGroup.Id
            ),
            // will be evaluated to false
            new Constraint__c(
                ReferencedField__c      = 'cBatterySize',
                Operator__c             = '>',
                ValueToMatch__c         = '15',
                Type__c                 = 'Number',
                ConstraintGroup__c      = oConstraintGroup.Id
            )
        };
        insert listConstraints;
    }

    /**
     * Test successful eService order creation
     */
    @IsTest
    static void insertOrderEServiceSuccessTest() {

        String DEBUG_HERE = DEBUG_HEADER + 'insertOrderEServiceSuccessTest() - ';

        setupStatic();

        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/order/';
        //request.addParameter('token', RESTService.ACCESS_TOKEN);
        request.httpMethod = 'POST';

        String sRequestJson = (String)JSON.serialize(requestDataRESTServiceOrder);
        request.requestBody = Blob.valueOf(sRequestJson);

        System.debug(DEBUG_HERE + 'Sent JSON: ' + JSON.serializePretty(requestDataRESTServiceOrder));

        // Set REST context
        RestContext.request  = request;
        RestContext.response = new RestResponse();

        // Insert contract
        RESTServiceOrder.Response oResponse = RESTServiceOrder.handlePost();

        Test.stopTest();

        System.debug(DEBUG_HERE + '------------------------------------------------------------------------');
        System.debug(DEBUG_HERE + 'Assertions');
        System.debug(DEBUG_HERE + '------------------------------------------------------------------------');

        if (RestContext.response.statusCode != 200) {
            System.debug(DEBUG_HERE + 'Response: ' + oResponse.error);
        }

        System.assertEquals(200, RestContext.response.statusCode, 'Expect status code 200');

        Opportunity oOpportunity = [
            SELECT
                Id,
                FirstName__c,
                LastName__c,
                Email__c,
                Phone__c,
                Salutation__c,
                Company__c,
                BillingSalutation__c,
                BillingStreet__c,
                BillingStreetNo__c,
                BillingPostalCode__c,
                BillingCity__c,
                BillingState__c,
                BillingCountryIsoCode__c,
                BillingAdditional__c,
                ShippingCompany__c,
                ShippingSalutation__c,
                ShippingSalutation2__c,
                ShippingFirstName__c,
                ShippingLastName__c,
                ShippingStreet__c,
                ShippingStreetNo__c,
                ShippingPostalCode__c,
                ShippingCity__c,
                ShippingState__c,
                ShippingCountryIsoCode__c,
                ShippingAdditional__c,
                ShippingPhone__c,
                (
                    SELECT
                        ContentDocumentId
                    FROM
                        ContentDocumentLinks
                ),
                (
                    SELECT
                        Id,
                        Quantity,
                        TotalPrice,
                        Product2Id
                    FROM
                        OpportunityLineItems
                )
            FROM
                Opportunity
            LIMIT 1
        ];

        //RESTServiceOrder.resolvePath(requestDataRESTServiceOrder, '');
        //--------------------------------------
        // Check addresses
        //--------------------------------------
        Map<String,Object> mapBillingAddress = (Map<String,Object>)requestDataRESTServiceOrder.get('billingAddress');
        System.assertEquals((String)mapBillingAddress.get('streetName'), oOpportunity.BillingStreet__c);
        System.assertEquals((String)mapBillingAddress.get('streetNumber'), oOpportunity.BillingStreetNo__c);
        System.assertEquals((String)mapBillingAddress.get('additionalStreetInfo'), oOpportunity.BillingAdditional__c);
        System.assertEquals((String)mapBillingAddress.get('postalCode'), oOpportunity.BillingPostalCode__c);
        System.assertEquals((String)mapBillingAddress.get('city'), oOpportunity.BillingCity__c);
        System.assertEquals((String)mapBillingAddress.get('state'), oOpportunity.BillingState__c);
        System.assertEquals((String)mapBillingAddress.get('country'), oOpportunity.BillingCountryIsoCode__c);

        Map<String,Object> mapShippingAddress = (Map<String,Object>)requestDataRESTServiceOrder.get('shippingAddress');
        System.assertEquals((String)mapShippingAddress.get('company'), oOpportunity.ShippingCompany__c);
        System.assertEquals((String)mapShippingAddress.get('salutation'), oOpportunity.ShippingSalutation__c);
        System.assertEquals((String)mapShippingAddress.get('salutation'), oOpportunity.ShippingSalutation2__c);
        System.assertEquals((String)mapShippingAddress.get('streetName'), oOpportunity.ShippingStreet__c);
        System.assertEquals((String)mapShippingAddress.get('streetNumber'), oOpportunity.ShippingStreetNo__c);
        System.assertEquals((String)mapShippingAddress.get('additionalStreetInfo'), oOpportunity.ShippingAdditional__c);
        System.assertEquals((String)mapShippingAddress.get('postalCode'), oOpportunity.ShippingPostalCode__c);
        System.assertEquals((String)mapShippingAddress.get('city'), oOpportunity.ShippingCity__c);
        System.assertEquals((String)mapShippingAddress.get('state'), oOpportunity.ShippingState__c);
        System.assertEquals((String)mapShippingAddress.get('country'), oOpportunity.ShippingCountryIsoCode__c);
        System.assertEquals((String)mapShippingAddress.get('phone'), oOpportunity.ShippingPhone__c);

        // General
        System.assertEquals((String)mapBillingAddress.get('company'), oOpportunity.Company__c);
        System.assertEquals((String)mapBillingAddress.get('salutation'), oOpportunity.Salutation__c);
        System.assertEquals((String)mapBillingAddress.get('firstName'), oOpportunity.FirstName__c);
        System.assertEquals((String)mapBillingAddress.get('lastName'), oOpportunity.LastName__c);

        // Phone and Email
        if (!String.isBlank((String)mapBillingAddress.get('email'))) {
            System.assertEquals((String)mapBillingAddress.get('email'), oOpportunity.Email__c);
        }
        else {
            System.assertEquals((String)mapShippingAddress.get('email'), oOpportunity.Email__c);
        }

        if (!String.isBlank((String)mapBillingAddress.get('phone'))) {
            System.assertEquals((String)mapBillingAddress.get('phone'), oOpportunity.Phone__c);
        }
        else {
            System.assertEquals((String)mapShippingAddress.get('phone'), oOpportunity.Phone__c);
        }

        //--------------------------------------
        // Check OpportunityLineItems
        //--------------------------------------
        Integer iProductsFound = 0;
        Id idMasterOpportunityLineItem;

        for (OpportunityLineItem oOpportunityLineItem : oOpportunity.OpportunityLineItems) {
            if (oOpportunityLineItem.Product2Id == mapProducts.get('eService').Id
                || oOpportunityLineItem.Product2Id == mapProducts.get('eServiceBundleProduct').Id) {
                iProductsFound++;

                if (oOpportunityLineItem.Product2Id == mapProducts.get('eService').Id) {
                    idMasterOpportunityLineItem = oOpportunityLineItem.Id;
                }
            }
        }
        System.assertEquals(2, iProductsFound, 'Count of OpportunityLineItems');

        //--------------------------------------
        // Check OrderInputDefinitionValues
        //--------------------------------------
        // All OrderInputDefinitionValues are related to the master product!
        // Also "Checkout" custom fields.
        List<OrderInputDefinitionValue__c> listOrderInputDefinitionValues = [
            SELECT
                Id,
                Opportunity__c,
                OpportunityLineItem__c,
                OrderInputDefinition__c,
                OrderInputDefinitionJunction__c,
                OrderInputDefinition__r.RecordType.DeveloperName,
                OrderInputDefinition__r.TermsAndConditionsType__c,
                TermsAndConditions__c,
                TermsAndConditionsTypeNote__c,
                Value__c
            FROM
                OrderInputDefinitionValue__c
            WHERE
                Opportunity__c = :oOpportunity.Id AND
                OpportunityLineItem__c = :idMasterOpportunityLineItem
        ];
        Integer iExpectedCount = mapOrderInputDefinitionsById.size() - 1; // -1 cUpfrontPayment!
        System.assertEquals(iExpectedCount, listOrderInputDefinitionValues.size() , 'Expected ' + iExpectedCount + ' created OrderInputDefinitionValues');

        // Get custom fields
        Map<String,Object> mapProductCustomFields = (Map<String,Object>)ConstraintValidator.resolvePath(requestDataRESTServiceOrder, 'lineItems.0.custom.fields');
        Map<String,Object> mapCheckoutCustomFields = (Map<String,Object>)ConstraintValidator.resolvePath(requestDataRESTServiceOrder, 'custom.fields');

        Map<String,Object> mapCustomFields = new Map<String,Object>();
        mapCustomFields.putAll(mapProductCustomFields);
        mapCustomFields.putAll(mapCheckoutCustomFields);

        // This TermsAndConditions should be selected
        List<TermsAndConditions__c> listTermsAndConditions = [SELECT Id, Type__c FROM TermsAndConditions__c WHERE Current__c = TRUE];
        Map<String,TermsAndConditions__c> mapTermsAndConditionsByType = new Map<String,TermsAndConditions__c>();

        for (TermsAndConditions__c oTermsAndConditions : listTermsAndConditions) {
            mapTermsAndConditionsByType.put(oTermsAndConditions.Type__c, oTermsAndConditions);
        }

        for (OrderInputDefinitionValue__c oOrderInputDefinitionValue : listOrderInputDefinitionValues) {

            System.assert(mapOrderInputDefinitionsById.containsKey(oOrderInputDefinitionValue.OrderInputDefinition__c));

            // Get according OrderInputDefinition
            OrderInputDefinition__c oOrderInputDefinition = mapOrderInputDefinitionsById.get(oOrderInputDefinitionValue.OrderInputDefinition__c);
            String sType = oOrderInputDefinitionValue.OrderInputDefinition__r.RecordType.DeveloperName;
            String sFieldId = oOrderInputDefinition.Id__c;
            String sValueActual = String.valueOf(oOrderInputDefinitionValue.Value__c);
            String sValueExpected = String.valueOf(mapCustomFields.get(sFieldId));

            if (sType == 'price') {

                // since 2018-05-07 (SOBCRM-1188)
                System.debug(DEBUG_HERE + 'Value for special field "' + sFieldId + '" of type "' + sType + '": ' + sValueActual);

                Map<String,Object> mapPrice = (Map<String,Object>)mapCustomFields.get(sFieldId);
                System.assertEquals(Integer.valueOf(mapPrice.get('centAmount')), Integer.valueOf(Decimal.valueOf(sValueActual)*100));
            }
            else if (sType == 'termsAndConditions') {

                String sTermsAndConditionType = oOrderInputDefinitionValue.OrderInputDefinition__r.TermsAndConditionsType__c;
                Id idTermsAndConditionSelected = oOrderInputDefinitionValue.TermsAndConditions__c;
                TermsAndConditions__c oTermsAndConditionsExpectedByType = mapTermsAndConditionsByType.get(sTermsAndConditionType);
                System.assert(oTermsAndConditionsExpectedByType != null);

                // since 2018-06-15 (SOBCRM-1189)
                System.debug(DEBUG_HERE + 'Terms and Conditions object for special field "' + sFieldId + '" of TermsAndConditions type "' + sTermsAndConditionType + '": ' + idTermsAndConditionSelected);

                System.assertEquals(idTermsAndConditionSelected, oTermsAndConditionsExpectedByType.Id, 'Expected another TermsAndConditions ID');
            }
            else {
                // Compare to input custom value from order
                System.assert(mapCustomFields.containsKey(sFieldId), 'Expected field "' + sFieldId + '"');

                System.debug(DEBUG_HERE + 'Value for field "' + sFieldId + '": ' + sValueActual);
                System.assertEquals(sValueExpected, sValueActual, 'Value for "' + sFieldId + '"');
            }
        }

        // Check on attached file
        System.assertEquals(2, oOpportunity.ContentDocumentLinks.size(), 'Expected two attached file to Opportunity');

        ContentVersion oContentVersion = [SELECT VersionData, VersionNumber FROM ContentVersion WHERE ContentDocumentId = :oOpportunity.ContentDocumentLinks.get(0).ContentDocumentId];

        String sFileContents = EncodingUtil.base64Decode(EncodingUtil.base64Encode(oContentVersion.VersionData)).toString();
        String sExpectedFileContents = (new RESTServiceOrder.AttachmentLoaderMockDispatcher()).RESPONSE_BODY;
        System.assertEquals(sFileContents, sExpectedFileContents);
    }

    /**
     * Test successful Bundle order creation
     *
     * @see https://interaktiv.jira.com/browse/SOBCRM-1256
     * @see https://interaktiv.jira.com/browse/SOBCRM-1271
     */
    @IsTest
    static void insertOrderBundleSuccessTest() {

        String DEBUG_HERE = DEBUG_HEADER + 'insertOrderBundleSuccessTest() - ';

        setupStatic();

        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/order/';
        //request.addParameter('token', RESTService.ACCESS_TOKEN);
        request.httpMethod = 'POST';

        String sRequestJson = (String)JSON.serialize(requestDataRESTServiceOrderBundleAU);
        request.requestBody = Blob.valueOf(sRequestJson);

        System.debug(DEBUG_HERE + 'Sent JSON: ' + JSON.serializePretty(requestDataRESTServiceOrderBundleAU));

        // Set REST context
        RestContext.request  = request;
        RestContext.response = new RestResponse();

        // Insert contract
        RESTServiceOrder.Response oResponse = RESTServiceOrder.handlePost();

        Test.stopTest();

        System.debug(DEBUG_HERE + '------------------------------------------------------------------------');
        System.debug(DEBUG_HERE + 'Assertions');
        System.debug(DEBUG_HERE + '------------------------------------------------------------------------');

        if (RestContext.response.statusCode != 200) {
            System.debug(DEBUG_HERE + 'Response: ' + oResponse.error);
        }

        System.assertEquals(200, RestContext.response.statusCode, 'Expect status code 200');

        Opportunity oOpportunity = [
            SELECT
                Id,
                PrimaryContact__r.Birthdate,
                BatteryCapacity__c,
                AustraliaCalculatedSubsidyAmount__c,
                TargetCountry__c,
                Language__c,
                CurrencyIsoCode,
                IsRestServiceOrderProcessed__c,
                WebOrderTotalPrice__c,
                (
                    SELECT
                        Id,
                        Quantity,
                        UnitPrice,
                        TotalPrice,
                        Product2Id,
                        Product2.StockKeepingUnit,
                        Product2.RecordType.DeveloperName,
                        WebOrderTotalPrice__c,
                        WebOrderUnitPrice__c
                    FROM
                        OpportunityLineItems
                )
            FROM
                Opportunity
            LIMIT 1
        ];

        System.assertEquals(AUSTRALIA_CURRENCY_CODE, oOpportunity.CurrencyIsoCode);
        System.assertEquals(AUSTRALIA_COUNTRY_CODE, oOpportunity.TargetCountry__c);
        System.assertEquals(AUSTRALIA_LANGUAGE_CODE, oOpportunity.Language__c);
        System.assert(oOpportunity.IsRestServiceOrderProcessed__c);

        System.assertEquals(
            (Decimal)ConstraintValidator.resolvePath(requestDataRESTServiceOrderBundleAU, 'totalPrice.centAmount')/100,
            oOpportunity.WebOrderTotalPrice__c,
            'Expected totalPrice to be set on Opportunity.WebOrderTotalPrice__c'
        );

        // Check Battery Size
        Decimal fCustomFieldBatterySize = (Decimal)ConstraintValidator.resolvePath(requestDataRESTServiceOrderBundleAU, 'lineItems.0.custom.fields.cBatterySize');
        System.assert(fCustomFieldBatterySize > 0, 'Battery Size should be greater 0');
        System.assertEquals(fCustomFieldBatterySize, oOpportunity.BatteryCapacity__c, 'Battery Size');

        System.debug(DEBUG_HERE + 'BatterySize: ' + fCustomFieldBatterySize);
        System.debug(DEBUG_HERE + 'AustraliaSetting__mdt: ' + mapAustralianSubsidySettings);
        System.debug(DEBUG_HERE + 'Subsidy: ' + oOpportunity.AustraliaCalculatedSubsidyAmount__c);

        Decimal fMaxSubsidyAmount = Decimal.valueOf(mapAustralianSubsidySettings.get('SubsidyMaxAmount'));

        if (fMaxSubsidyAmount > 0) {
            System.assertEquals(fMaxSubsidyAmount, oOpportunity.AustraliaCalculatedSubsidyAmount__c);
        }

        // Opportunity Line Items
        System.debug(DEBUG_HERE + 'OpportunityLineItems: ' + JSON.serializePretty(oOpportunity.OpportunityLineItems));
        System.assertEquals(oOpportunity.OpportunityLineItems.size(), 5, 'OpportunityLineItems'); // Every SKU should be reflected by a line item

        List<OrderInputDefinitionValue__c> listOrderInputDefinitionValues = [
            SELECT
                Opportunity__c,
                OpportunityLineItem__c,
                OpportunityProductLink__c,
                Order__c,
                OrderInputDefinition__c,
                OrderInputDefinitionFieldId__c,
                OrderInputDefinitionJunction__c,
                OrderInputDefinitionLabel__c,
                OrderInputDefinitionTargetField__c,
                OrderItem__c,
                TermsAndConditions__c,
                TermsAndConditionsTypeNote__c,
                Value__c
            FROM OrderInputDefinitionValue__c
            WHERE Opportunity__c = :oOpportunity.Id
        ];
        System.debug(DEBUG_HERE + 'Created OrderInputDefinitionValue__c: ' + JSON.serializePretty(listOrderInputDefinitionValues));
        System.debug(DEBUG_HERE + 'Created OpportunityLineItems: ' + JSON.serializePretty(oOpportunity.OpportunityLineItems));

        // Check LineItems on values
        for (OpportunityLineItem oOpportunityLineItem : oOpportunity.OpportunityLineItems) {

            String sSKU = oOpportunityLineItem.Product2.StockKeepingUnit;
            String sPricebookMapKey = AUSTRALIA_CURRENCY_CODE + '-' + sSKU;
            // String sRecordTypeName = oOpportunityLineItem.Product2.RecordType.DeveloperName;

            switch on sSKU {

                when 'bundle-UNITTEST' {

                    System.assertEquals(
                        (Decimal)ConstraintValidator.resolvePath(requestDataRESTServiceOrderBundleAU, 'lineItems.0.price.value.centAmount')/100,
                        oOpportunityLineItem.WebOrderUnitPrice__c,
                        'Expect Web Order line item price to match OpportunityLineItem.WebOrderUnitPrice__c'
                    );

                    System.assertEquals(
                        (Decimal)ConstraintValidator.resolvePath(requestDataRESTServiceOrderBundleAU, 'lineItems.0.totalPrice.centAmount')/100,
                        oOpportunityLineItem.WebOrderTotalPrice__c,
                        'Expect Web Order line item price to match OpportunityLineItem.WebOrderTotalPrice__c'
                    );
                }

                when 'financing-UNITTEST' {
                    Integer iUpfrontPaymentCent = (Integer)ConstraintValidator.resolvePath(requestDataRESTServiceOrderBundleAU, 'customLineItems.0.custom.fields.cUpfrontPayment.centAmount');
                    Decimal fUpfrontPayment = iUpfrontPaymentCent/100;
                    System.assertEquals(fUpfrontPayment, oOpportunityLineItem.TotalPrice, sSKU + ' Expected Upfront Amount as TotalPrice');
                }

                when 'sonnenBattery-UNITTEST', 'battery-installation-UNITTEST' {
                    System.assertEquals(mapPricebookEntries.get(sPricebookMapKey).UnitPrice, oOpportunityLineItem.TotalPrice, sSKU + 'Expected TotalPrice to match ProductEntry.UnitPrice');
                }

                when 'subsidy-UNITTEST' {
                    if (oOpportunity.AustraliaCalculatedSubsidyAmount__c > 0) {

                        // Todo: Subsidy has now
                        System.assertEquals(
                            oOpportunity.AustraliaCalculatedSubsidyAmount__c * -1,
                            oOpportunityLineItem.TotalPrice,
                            sSKU + 'Expected TotalPrice to match oOpportunity.AustraliaCalculatedSubsidyAmount__c'
                        );
                    }
                }
            }
        }

        // Check on created Order
        List<Order> listOrders = [
            SELECT
                Id,
                (
                    SELECT
                        Product2Id,
                        Quantity,
                        PricebookEntryId,
                        UnitPrice
                    FROM
                        OrderItems
                )
            FROM
                Order
            WHERE
                OpportunityId = :oOpportunity.Id
        ];

        System.assertEquals(1, listOrders.size(), 'Expected exactly 1 Order');
        Order oOrder = listOrders.get(0);

        System.assertEquals(1, oOrder.OrderItems.size(), 'Expected 1 Order Item');
    }
}