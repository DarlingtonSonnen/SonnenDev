/**
 * LogUtil class for advanced debugging.
 * This class configuration can be extended in in custom setting DiaLogConfig__c for custom logging.
 * 
 * Usage: 
 * - initialization
 *      LogUtil log = new LogUtil();                for default error config
 *      
 *      OR
 *
 *      LogUtil log = new LogUtil('custom_mode');   for custom error config
 *      ** replace custom_mode with custom setting name
 *
 *  - execution with various logLevels
 *      log.info(String name, Exception e, String addInfos)
 *      log.warn(String name, Exception e, String addInfos)
 *      log.error(String name, Exception e, String addInfos)
 *      
 *
 * @version     2016-06-08  kevin.kolditz@die-interaktiven.de      first version
 *              
 */

public class LogUtil {
    
    // error record contains all error relevant data
    public static sObject error {get;set;}
    
    // custom setting entry which defines the initial config mode
    public static DiaLogConfig__c configMode {get;set;}
    
    public static Map<String, DiaLogConfig__c> configMap;

    public static String mode;
    
    /**
     * Default constructor
     */
    public LogUtil(){

        configMap = DiaLogConfig__c.getAll();
        mode = 'Default';

        if (configMap.get(mode) == null) {

            initialSetup();
            configMap = DiaLogConfig__c.getAll();
        }

        configMode = configMap.get(mode);

        error = Schema.getGlobalDescribe().get(configMode.Log_Object_Name__c ).newSObject();

    }
    
    /**
     * Custom constructor for logging with another log setting
     */
    public LogUtil(String logMode){

        mode = logMode;   
        configMap = DiaLogConfig__c.getAll();
        
        if (configMap.get(mode) == null) {
            
            mode = 'Default';   
            System.debug('Error Mode ' + mode + ' not available. Using default diasyslog config.'); 
        }

        if (configMap.get(mode) == null) {

            initialSetup();
            configMap = DiaLogConfig__c.getAll();
        }
            
        configMode = configMap.get(mode);
        error = Schema.getGlobalDescribe().get(configMode.Log_Object_Name__c ).newSObject();               
            
    }
    
    /**
     * Logging method for info level.
     *
     * @param      name      The Name of the current class
     * @param      addInfos  Additional infos for the log entry.
     *
     */
    public void info(String name, String addInfos) {
        error.put(configMode.Severity_API_Field__c, 'INFO');
        debugFactory('info',name, null, addInfos);
    }

    /**
     * Logging method for warn level.
     *
     * @param      name      The Name of the current class
     * @param      addInfos  Additional infos for the log entry.
     *
     */
    public void warn(String name, String addInfos) {

        error.put(configMode.Severity_API_Field__c, 'WARN');
        debugFactory('warn',name, null, addInfos);
    }

    /**
     * Logging method for error level.
     *
     * @param      name      The Name of the current class
     * @param      addInfos  Additional infos for the log entry.
     *
     */    
    public void error(String name, String addInfos) {

        error.put(configMode.Severity_API_Field__c, 'ERROR');
        debugFactory('error',name, null, addInfos);
    }


    /**
     * Logging method for info level with exception support.
     *
     * @param      name      The Name of the current class
     * @param      addInfos  Additional infos for the log entry.
     * @param      e         Exception that has to be logged
     */
    public void info(String name, String addInfos, Exception e) {

        error.put(configMode.Severity_API_Field__c, 'INFO');
        debugFactory('info',name, e, addInfos);
    }

    /**
     * Logging method for warn level with exception support.
     *
     * @param      name      The Name of the current class
     * @param      addInfos  Additional infos for the log entry.
     * @param      e         Exception that has to be logged
     */
    public void warn(String name, String addInfos, Exception e ) {

        error.put(configMode.Severity_API_Field__c, 'WARN');
        debugFactory('warn',name, e, addInfos);
    }
    
    /**
     * Logging method for warn level with exception support.
     *
     * @param      name      The Name of the current class
     * @param      addInfos  Additional infos for the log entry.
     * @param      e         Exception that has to be logged
     */
    public void error(String name, String addInfos, Exception e) {

        error.put(configMode.Severity_API_Field__c, 'ERROR');
        debugFactory('error',name, e, addInfos);
    }    
    
    /**
     * Method calls the logging methods for system debug logging, email sending of
     * sObject creation  
     *
     * @param      logLevel  The log level
     * @param      name      The name
     * @param      e         Exception that has to be logged
     * @param      addInfos  The add infos
     */
    private static void debugFactory(String logLevel, String name, Exception e, String addInfos) {
        
        if (configMode.Logging_Active__c == true) {
            
            String debugString =    'LogUtil - ' + 
                                    ' Severity: ' + logLevel + 
                                    ' Name: ' + name +
                                    ' Infos: ' + addInfos;

            if (e != null) {

                debugString += ' Exception Msg: ' + e.getMessage(); 
                debugString += ' Exception Stack Trace: ' + e.getStackTraceString(); 
            }     

            if (configMode.Email_Notification__c != null && configMode.Email_Notification__c.contains(logLevel)) {
                
                sendEmailToAdmin(debugString);
            }

            if (configMode.sObject_Logging__c != null && configMode.sObject_Logging__c.contains(logLevel)) {
                
                createLogEntry(name, e, addInfos);
            }

            if (configMode.System_Debug__c != null && configMode.System_Debug__c.contains(logLevel)) {
      
                System.debug(debugString);
            }        
        }
    }

    /**
     * Creates a log record and triggers the 
     *
     * @param      name      The name
     * @param      e         { parameter_description }
     * @param      addInfos  The add infos
     *
     * @return     { description_of_the_return_value }
     */
    private static void createLogEntry(String name, Exception e, String addInfos) {
        
        // set name and cut if too long
        String newName = name + ' - ' + String.valueOf(DateTime.now());
        if (newName.length() <= 80) {

            error.put('Name',newName);
        } else {
            error.put('Name',newName.subString(0, 80));
        }
        
        if (e != null) {

            // set type and cut if too long
            if (e.getTypeName().length() <= 255) {

                error.put(configMode.Type_API_Field__c,e.getTypeName());
            } else {
                error.put(configMode.Type_API_Field__c,e.getTypeName().subString(0, 255));
            }
            
            // set line number
            error.put(configMode.Line_Number_API_Field__c, e.getLineNumber());
            
            // set message and cut if too long
            if (e.getMessage().length() <= 32768) {

                error.put(configMode.Message_API_Field__c, e.getMessage());
            } else {
                error.put(configMode.Message_API_Field__c, e.getMessage().subString(0, 255));
            }
            
            // set stack trace and cut if too long
            if (e.getStackTraceString().length() <= 32768) {

                error.put(configMode.Stack_Trace_API_Field__c, e.getStackTraceString());
            } else {
                error.put(configMode.Stack_Trace_API_Field__c, e.getStackTraceString().subString(0, 255));
            }
        }
        
        // set additional information and cut if too long
        if (addInfos != null) {
            if (addInfos.length() <= 32768) {

                error.put(configMode.Additional_Information_API_Field__c,addInfos);
            } else {
                error.put(configMode.Additional_Information_API_Field__c, addInfos.subString(0, 32768));
            }
        }
        
        // make a future call for the insert of the log entries
        insertSOjects(configMap.get(mode).Log_Object_Name__c, JSON.serialize(error));

    }


    /**
     * Future method to insert an error log entry.
     *
     * @param      sObjectApiName  The sObject api name
     * @param      jSONSObject     The serialized error as a json object
     */
    //@future
    private static void insertSOjects(String sObjectApiName, String jSONSObject)
    {
        Map<String, Object> fieldMap = (Map<String, Object>)JSON.deserializeUntyped(jSONSObject);
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(sObjectApiName);
        SObject newSobject = targetType.newSObject();

        Map<String, Schema.sObjectField> targetFields = targetType.getDescribe().fields.getMap();
        for (String key : fieldMap.keySet()) {

            if (key == 'attributes') {
                continue;
            }

            Object value = fieldMap.get(key);
            Schema.DisplayType valueType = targetFields.get(key).getDescribe().getType();
            if (value instanceof String && valueType != Schema.DisplayType.String) {

                String svalue = (String)value;
                //if (valueType == Schema.DisplayType.Date)
                //    newSobject.put(key, Date.valueOf(svalue));
                //else if(valueType == Schema.DisplayType.DateTime)
                //    newSobject.put(key, DateTime.valueOfGmt(svalue));
                //else if (valueType == Schema.DisplayType.Percent || valueType == Schema.DisplayType.Currency)
                //    newSobject.put(key, svalue == '' ? null : Decimal.valueOf(svalue));
                //else if (valueType == Schema.DisplayType.Double)
                //    newSobject.put(key, svalue == '' ? null : Double.valueOf(svalue));
                //else if (valueType == Schema.DisplayType.Integer)
                //    newSobject.put(key, Integer.valueOf(svalue));
                //else if (valueType == Schema.DisplayType.Base64)
                //    newSobject.put(key, Blob.valueOf(svalue));
                //else
                    newSobject.put(key, svalue);
            } else {

                newSobject.put(key, value);
            }
        }
        insert newSobject;
    }

    /**
     * Method sends an email to the recipient addresses defined in the custom setting 
     *
     * @param      debugString  The debug string
     */
    private static void sendEmailToAdmin (String debugString) {
        
        List<String> devMailAddressList = new List<String>();
        
        if (configMode.Admin_Email_Addresses__c != null) {
                
            devMailAddressList = configMode.Admin_Email_Addresses__c.toLowerCase().replace(' ', '').split(',',10);
                    
            Messaging.SingleEmailMessage mail=new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[] {};

            for (String d : devMailAddressList) {
                toAddresses.add(d);
            }

            mail.setToAddresses(toAddresses);
            mail.setSenderDisplayName('DiaSysLog message');
            mail.setSubject('Log from Org : ' + UserInfo.getOrganizationName());
            mail.setPlainTextBody(debugString);

            try {

                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });             
            } catch (Exception e) {

                System.debug('Error while sending Log email: ' + e.getMessage());
            }
        }
    }    

    /**
     * Method creates a default log record for the custom object. This method will be executed if there is no 
     * default setting is found 
     */
    public static void initialSetup () {

        DiaLogConfig__c testDefaultConf = new DiaLogConfig__c(
            
            Logging_Active__c                   = true,
            sObject_Logging__c                  = 'warn, error', 
            Type_API_Field__c                   = 'Type__c', 
            System_Debug__c                     = 'info, warn, error', 
            Stack_Trace_API_Field__c            = 'Stack_Trace__c', 
            Name                                = 'Default', 
            Message_API_Field__c                = 'Message__c', 
            Severity_API_Field__c               = 'Severity__c', 
            Line_Number_API_Field__c            = 'Line_Number__c', 
            Log_Object_Name__c                  = 'DiaSysLog__c', 
            Email_Notification__c               = 'error',
            Admin_Email_Addresses__c            = 'kevin.kolditz@die-interaktiven.de', 
            Additional_Information_API_Field__c = 'Additional_Information__c'
        );

        insert testDefaultConf;
    }

}