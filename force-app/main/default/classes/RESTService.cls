/**
 * Base class for REST Services
 *
 * Since static methods cannot be inheritated this is used
 * as a base toolset for REST Services
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.5.0 (2016-10-21)
 */
public class RESTService {

    public static final String ACCESS_TOKEN = 'bZt3OiukHn2Gteh_Kjh';

    /**
     * Authenticate via send token GET parameter
     */
    public static Boolean isAuthenticated(DiaRESTResponse response) {

        RestRequest request = RestContext.request;
        String token = request.params.get('token');

        if (token == NULL || token != ACCESS_TOKEN) {
            RestContext.response.statusCode = 403;
            response.setError('Zugriff verweigert', 'ACCESS_DENIED');
            return FALSE;
        }

        return TRUE;
    }
}