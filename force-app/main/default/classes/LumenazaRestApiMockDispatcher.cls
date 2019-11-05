/**
 * Mock Dispatcher for Lumenaza API Calls
 *
 * Changelog
 *
 * v1.5.0-2018-04-05 (marko@die-interaktiven.de)
 * - Added route for "contractChange" to switch a contract to a new type (SOBCRM-1164)
 *
 * v1.4.0 (MSB 2016-12-15)
 * - Added route for "contractAdd" to add a new Contract to an existing
 *   Customer at Lumenaza
 *
 * v1.3.0 (MSB 2106-12-14)
 * - Implemented routes for "changeAdd" and "changesCheck" in the course of the
 *   implementation of the Lumenaza Contract Change mechanism (SOBCRM-669)
 * - Added setForcedResponseIfAvailable() which forces a result set by
 *   setResultBodyNextRoute() before
 *
 * v1.2.0 (MSB 2016-10-06)
 * - Implemented route for revokation of contract (SOBCRM-668)
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.5.0-2018-04-05
 */
public class LumenazaRestApiMockDispatcher implements HttpCalloutMock {

    private static final String DEBUG_HEADER = 'LumenazaRestApiMockDispatcher';
    public static String CONTRACT_ID = '987654321';
    public static String CUSTOMER_ID = '123456789';

    private static String nextRouteBody;
    private static Integer nextRouteStatusCode;

    // Methods and routes
    private Map<String,String> routes = new Map<String,String>{
		'oauthToken'                    => 'POST:/oauth/token/',
		'contractCreate'                => 'POST:/v3/consumers/create/',
        'contractAdd'                   => 'POST:/v3/consumers/[^/]+/contracts/add_contract/',
        'contractRevoke'                => 'POST:/v3/consumers/[^/]+/contracts/[^/]+/revoke/',
		'changeAdd'                     => 'POST:/v3/master_data/changes/',
		'changesCheck'                  => 'GET:/v3/master_data/changes/',
        'bonusAdd'                      => 'POST:/v3/consumers/[^/]+/contracts/[^/]+/add_bonus/',
        'synchronizeInvoicesSummarized' => 'GET:/v3/bss_documents/customer_statistics/summarized/[0-9]+/[0-9]+/',
        'contractInfo'                  => 'GET:/v3/consumers/[^/]+/contracts/[^/]+/',
        'meterUpsert'                   => 'POST:/v3/meter/create/',
        'synchronizeInvoicesSummarized' => 'GET:/v3/bss_documents/customer_statistics/summarized/[0-9]+/[0-9]+/',
        'contractChange'                => 'PUT:/v3/consumers/[^/]+/contracts/[^/]+/contract_change/'
    };

    private HttpRequest request;
    private HttpResponse response;

    /**
     * Implemented method from interface as route dispatcher
     */
    public HttpResponse respond(HttpRequest request) {

		this.response = new HttpResponse();
        this.request = request;
        this.response.setHeader('Content-Type', 'application/json');

        String path = this.getEndpointPath(request.getEndpoint());
        String method = request.getMethod().toUpperCase();

        Boolean routeFound = false;

        for (String routeMethod : routes.keySet()) {

            String routePattern = routes.get(routeMethod);
            String routeString = method + ':' + path;
            Boolean hasRoute = false;

            if (Pattern.compile(routePattern).matcher(routeString).matches()) {

                System.debug('LumenazaRestApiMockDispatcher - Route method for path ' + routeString + ': ' + routeMethod);

                if (routeMethod == 'changeAdd') {
                    this.routeChangeAdd();
                    routeFound = true;
                    break;
                }
                else if (routeMethod == 'changesCheck') {
                    this.routeChangeCheck();
                    routeFound = true;
                    break;
                }
                else if (routeMethod == 'contractRevoke') {
                    this.routeContractRevoke();
                    routeFound = true;
                    break;
                }
                else if (routeMethod == 'contractCreate') {
					this.routeContractCreate();
                    routeFound = true;
                	break;
                }
                else if (routeMethod == 'contractAdd') {
					this.routeContractAdd();
                    routeFound = true;
                	break;
                }
                else if (routeMethod == 'oauthToken') {
					this.routeOauthToken();
                    routeFound = true;
                	break;
                }
                else if (routeMethod == 'bonusAdd') {
					this.routeBonusAdd();
                    routeFound = true;
					break;
                }
                else if (routeMethod == 'synchronizeInvoicesSummarized') {
					this.routeSynchronizeInvoicesSummarized();
                    routeFound = true;
					break;
                }
                else if (routeMethod == 'contractInfo') {
					this.routeContractInfo();
                    routeFound = true;
					break;
                }
                else if (routeMethod == 'meterUpsert') {
					this.routeMeterUpsert();
                    routeFound = true;
					break;
                }
                else if (routeMethod == 'contractChange') {
					this.routeContractChange();
                    routeFound = true;
					break;
                }

				throw new LumenazaRestApiMockDispatcherException('Unhandled route method "' + routeMethod + '"');
            }
        }

        if (routeFound == false) {
			throw new LumenazaRestApiMockDispatcherException('Unhandled route "' + path + '" with method ' + method);
        }

        return this.response;
    }

    //============================================================================
    // ROUTE HANDLERS
    //============================================================================

    /**
     * Fetch Contract info
     */
    private void routeContractInfo() {
        if (!this.setForcedResponseIfAvailable()) {
            this.response.setBody('{"deliv_address_street":"Charlotte-Bamberg-Str.","deliv_address_house_number":"2","deliv_address_zipcode":"35578","deliv_address_city":"Wetzlar","deliv_address_addition":"","saas_contract_id":"C18124850-1","annual_consumption":10000.0,"status_info":"keine Statusinformation vorhanden.","meter_id":["7147192"],"preferred_delivery_start":"2018-02-10","previous_provider":"9904383000003","subscription_reason":"E01","reg_status":"open_join","contract_termination_date":null,"order_date":"2018-01-10","delivery_end":null,"delivery_start":null,"deliv_status":"not_delivering","contract_parameters":{},"tariff_type":["package"],"bonuses":[]}');
            this.response.setStatusCode(200);
        }
    }

    /**
     * Invoices
     */
    private void routeMeterUpsert() {
        if (!this.setForcedResponseIfAvailable()) {
            this.response.setBody('Test');
            this.response.setStatusCode(201); // OK with empty body
        }
    }

    private void routeSynchronizeInvoicesSummarized() {
        if (!this.setForcedResponseIfAvailable()) {
            this.response.setBody(
                'customerID;SEPA-Mandatsreferenznummer;SEPA-Mandatsdatum;Vertragsnummer;delivery_start;delivery_end;customer_label;Installment date;Adressatentyp;company name;company_contact;last_name;first_name;sex;deliv_street;deliv_house_nr;Adresszusatz;deliv_zip_code;deliv_city;Zählpunkt-Nr.;Rechnungsnummer;Rechnungsdatum;Datum Abbuchung;Abschlags-Summe;Bonus-ID' + '\n' +
                '"DE16923049";"100270000001";24.02.2016;C16923049-1;01.01.2017;;existing;01.03.2017;1;;;Pampel;Hanse;Herr;Am Bischofsholz;"11";;"04288";Leipzig;DE0009990428800000000000000515196;2017002753;01.03.2017;01.03.2017;19.17;""' + '\n' +
                '"DE16775374";"100690000001";12.04.2016;C16775374-1;01.06.2016;;existing;01.03.2017;1;;;Test;Manfred;Herr;Erlenstr.;"6";;"57234";Wilnsdorf;DE0001815723400000301300000000821;2017002321;01.03.2017;01.03.2017;200.95;""' + '\n' +
                '"DE16805869";"111770000001";29.08.2016;C16805869-1;01.01.2017;;existing;01.03.2017;1;;;Schneider;Helge;Herr;Langgartenstr.;"7";;"54338";Schweich;DE0001815433800000101700000044246;2017002305;01.03.2017;01.03.2017;0.00;""' + '\n' +
                '"DE16590510";"102430000001";08.04.2016;C16590510-1;06.07.2016;;existing;01.03.2017;1;;;Mustermann;Andrea;Frau;Arthur-Müller-Str.;"36A";;"12487";Berlin;DE0000801248700000000000080576925;2017002222;01.03.2017;01.03.2017;-17.25;"a0f24000006hfKS"'
            );
            this.response.setStatusCode(200);
        }
    }

	/**
	 * Set reponse for Contract CREATE
	 */
    private void routeContractCreate() {
        if (!this.setForcedResponseIfAvailable()) {
            this.response.setBody('{"contract_id":"' + CONTRACT_ID + '","consumer_id":"' + CUSTOMER_ID + '"}');
            this.response.setStatusCode(200);
        }
    }

	/**
	 * Set reponse for adding a Contract to an
	 * existing Customer at Lumenaza
	 */
    private void routeContractAdd() {
        if (!this.setForcedResponseIfAvailable()) {
            this.response.setBody('{"contract_id":"' + CONTRACT_ID + '","consumer_id":"' + CUSTOMER_ID + '"}');
            this.response.setStatusCode(200);
        }
    }

	/**
	 * Set reponse for Contract UPDATEs by sending changes
	 */
    private void routeChangeAdd() {
        String sId = DiaUtilities.generateRandomString(25) + '.' + Datetime.now().millisecondGmt();
        this.response.setBody('{"change_id": "' +  sId + '"}');
        this.response.setStatusCode(200);
    }

	/**
	 * Set reponse for Contract change query
	 */
    private void routeChangeCheck() {
        if (!this.setForcedResponseIfAvailable()) {
            this.response.setBody('[{"change_id": "123", "status": "stored"}]');
            this.response.setStatusCode(200);
        }
    }

	/**
	 * Set reponse for Contract UPDATE
	 */
    private void routeContractRevoke() {
        this.response.setBody('{"detail": "contract successfully revoked"}');
        this.response.setStatusCode(200);
    }

	/**
	 * Set reponse for oAuth token
	 */
    private void routeOauthToken() {
        this.response.setBody('{"access_token": "TESTTOKEN1234", "token_type": "Bearer", "expires_in": 36000}');
        this.response.setStatusCode(200);
    }

    /**
     * Set response for bonus add
     */
    private void routeBonusAdd() {
        this.response.setBody('{"contract_id": "123456", "bonusID": "123456"}');
        this.response.setStatusCode(200);
    }

    /**
     * Set reponse for Contract Change
     */
    private void routeContractChange() {
        if (!this.setForcedResponseIfAvailable()) {
            this.response.setBody('{"contract_id":"' + CONTRACT_ID + '","consumer_id":"' + CUSTOMER_ID + '"}');
            this.response.setStatusCode(200);
        }
    }

    //============================================================================
    // HELPER
    //============================================================================
    /**
     * Force a result
     */
    public static void setResultBodyNextRoute(String body, Integer statusCode) {
        nextRouteBody = body;
        nextRouteStatusCode = statusCode;
    }

    /**
     * Set forced Response if available
     */
    private Boolean setForcedResponseIfAvailable() {

        if (nextRouteBody != NULL) {
            this.response.setBody(nextRouteBody);
            this.response.setStatusCode(nextRouteStatusCode);
            nextRouteBody = NULL;
            nextRouteStatusCode = NULL;
            return TRUE;
        }

        return FALSE;
    }

    /**
     * Extracts a path from an URL
     */
    private String getEndpointPath(String url) {

        Matcher matcher = Pattern.compile('^https?://[^/]+(.+)').matcher(url);
        String path = '';

        if (matcher.matches()) {
            path = matcher.group(1);
        }

        return path;
    }

   	public class LumenazaRestApiMockDispatcherException extends Exception {}
}