/**
 * Invocable email sender
 *
 * Changelog
 * ---------
 *
 * v1.0.0   2018-10-29  Marko Schmalenbach          Initial
 * v1.0.1   2018-10-29  Marko Schmalenbach          Unset booleans have a default value according to class SingleEmailMessage.
 *                                                  If they are given but NULL they default to false.
 * v1.0.2   2018-10-29  Marko Schmalenbach          Prevent sending with template if template is not active
 * v1.1.0   2018-10-30  Marko Schmalenbach          Added request field "fieldOnObjectToSetOnSuccess" to set a generic field of the "What" object
 * v1.2.0   2018-11-01  Marko Schmalenbach          Added request field "fieldOnObjectToSetResultStringTo" to set the result of the sending to
 * v1.3.0   2018-11-15  Marko Schmalenbach          Fix: Added VALID_RESULT_STRING_FIELD_TYPES to cover also TEXTAREA
 *
 * @since 2018-10-29
 * @see InvocableEmailSender_Test
 */
public class InvocableEmailSender {

    private static final String DEBUG_HEADER = 'InvocableEmailSender.';

    public static String TEST_ERROR_MESSAGE;

    private static final Set<String> VALID_RESULT_STRING_FIELD_TYPES = new Set<String>{'STRING', 'TEXTAREA'};


    /**
     * Invocable method
     *
     * @param requests
     *
     * @return
     */
    @InvocableMethod (Label='Send SingleEmailMessages')
    public static List<InvocableEmailSenderResult> sendEmails(List<InvocableEmailSenderRequest> requests) {

        final String DEBUG_HERE = DEBUG_HEADER + 'sendEmails() - ';

        List<InvocableEmailSenderResult> results = new List<InvocableEmailSenderResult>();
        List<SObject> listSObjectsToUpdate = new List<SObject>();

        for (InvocableEmailSenderRequest request : requests) {

            InvocableEmailSenderResult oResult = sendEmail(request);

            // Handle generic "What" object field on success
            if (request.whatId != null) {

                Map<String, String> mapFields = new Map<String, String>{
                    'Id' => request.whatId
                };

                Type oSObjectType = Type.forName(String.valueOf(Id.valueOf(mapFields.get('Id')).getSobjectType()));

                // Set fieldOnObjectToSetOnSuccess generically
                // This can be set by a formula in Process Builder e.g.:
                // 'OrderConfirmationEmailLastSentDate__c=' & SUBSTITUTE(TEXT(NOW()), ' ', 'T')
                if (oResult.sent && String.isNotBlank(request.fieldOnObjectToSetOnSuccess)) {

                    System.debug(DEBUG_HERE + 'Handle fieldOnObjectToSetOnSuccess: ' + request.fieldOnObjectToSetOnSuccess);

                    List<String> listFieldAndValue = request.fieldOnObjectToSetOnSuccess.split('=', 2);

                    if (listFieldAndValue.size() == 2) {

                        String sObjectField = listFieldAndValue.get(0).trim();
                        String sObjectValue = listFieldAndValue.get(1).trim();

                        mapFields.put(sObjectField, sObjectValue);
                    }
                }

                // If a field is set to set the result of the email sending to
                if (String.isNotBlank(request.fieldOnObjectToSetResultStringTo)) {

                    // Get field Describe to check if field exists and is of type String
                    String sFieldForResultString = request.fieldOnObjectToSetResultStringTo;
                    Map<String, SObjectField> mapDescribeFields = Schema.getGlobalDescribe().get(oSObjectType.getName()).getDescribe().fields.getMap();

                    System.debug(DEBUG_HERE + 'Handle fieldOnObjectToSetResultStringTo: ' + sFieldForResultString);

                    if (mapDescribeFields.containsKey(sFieldForResultString)) {

                        DescribeFieldResult oDescribeFieldResult = mapDescribeFields.get(sFieldForResultString).getDescribe();

                        if (VALID_RESULT_STRING_FIELD_TYPES.contains(String.valueOf(oDescribeFieldResult.getType()))) {

                            String sMessage = oResult.resultMessage;
                            Integer iMaxLength = oDescribeFieldResult.getLength();

                            // Shorten the message to the max length of the field
                            mapFields.put(
                                sFieldForResultString,
                                sMessage.length() > iMaxLength ? sMessage.substring(0, iMaxLength) : sMessage
                            );
                        }
                        else {
                            System.debug(DEBUG_HERE + 'Field "' + sFieldForResultString + '" is not of type ' + VALID_RESULT_STRING_FIELD_TYPES + ', so result cannot be set');
                        }
                    }
                }

                if (mapFields.size() > 1) {

                    try {

                        SObject oSObject = (SObject)JSON.deserialize(JSON.serialize(mapFields), oSObjectType);

                        System.debug(DEBUG_HERE + 'Update SObject: ' + oSObject);

                        listSObjectsToUpdate.add(oSObject);
                    }
                    catch (Exception e) {
                        System.debug(DEBUG_HERE + 'Could not create SObject with field "' + request.fieldOnObjectToSetOnSuccess + '": ' + e.getMessage());
                    }
                }
            }

            results.add(oResult);
        }

        if (!listSObjectsToUpdate.isEmpty()) {
            Database.update(listSObjectsToUpdate, false); // All or nothing false
        }

        return results;
    }

    /**
     * Send an email according to the given request
     *
     * @param request
     *
     * @return
     */
    public static InvocableEmailSenderResult sendEmail(InvocableEmailSenderRequest request) {

        final String DEBUG_HERE = DEBUG_HEADER + 'sendEmail() - ';

        System.debug(DEBUG_HERE + 'Given request: ' + request);

        Id idFromAddress;
        Id idTemplate;

        InvocableEmailSenderResult oSendEmailActionResult = new InvocableEmailSenderResult();
        oSendEmailActionResult.sent = false;
        oSendEmailActionResult.resultMessage = 'ERROR - ' + System.now() + ' - Unknown ';

        try {

            if (TEST_ERROR_MESSAGE != null) {
                throw new InvocableEmailSenderException(TEST_ERROR_MESSAGE);
            }

            if (request.orgWideFromEmail != null) {
                idFromAddress = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = :request.orgWideFromEmail].Id;
                System.debug(DEBUG_HERE + 'Id of OrgWideEmailAddress: ' + idFromAddress);
            }

            if (request.apiTemplateName != null) {
                // Only if template is active!
                try {
                    idTemplate = [SELECT Id FROM EmailTemplate WHERE IsActive = TRUE AND DeveloperName = :request.apiTemplateName].Id;
                }
                catch (Exception e) {
                    String sMessage = 'No active EmailTemplate with API name "' + request.apiTemplateName + '" found (' + e.getMessage() + ')';
                    throw new InvocableEmailSenderException(sMessage);
                }

                System.debug(DEBUG_HERE + 'Id of EmailTemplate: ' + idTemplate);
            }

            Messaging.SingleEmailMessage oSingleEmailMessage = new Messaging.SingleEmailMessage();
            oSingleEmailMessage.setTreatTargetObjectAsRecipient(false);

            // Sender Address
            if (idFromAddress != null) {
                oSingleEmailMessage.setOrgWideEmailAddressId(idFromAddress);
            }

            // Template ID
            if (idTemplate != null) {
                oSingleEmailMessage.setTemplateId(idTemplate);
            }
            // Otherwise manually
            else {
                oSingleEmailMessage.setSubject(request.subject);
                oSingleEmailMessage.setHtmlBody(request.htmlBody);
                oSingleEmailMessage.setPlainTextBody(request.textBody);
                oSingleEmailMessage.setTreatBodiesAsTemplate(forceBoolean(request.treatBodiesAsTemplate));
            }

            // Recipients
            oSingleEmailMessage.setToAddresses(getStringListFromCommaString(request.toAddress));

            // Cc
            if (String.isNotBlank(request.ccAddresses)) {
                oSingleEmailMessage.setCcAddresses(getStringListFromCommaString(request.ccAddresses));
            }

            // Bcc
            if (String.isNotBlank(request.bccAddresses) && !isComplianceBccEnabled()) {
                oSingleEmailMessage.setBccAddresses(getStringListFromCommaString(request.bccAddresses));
            }

            // Attachment documents
            // List of IDs of Document, ContentVersion, or Attachment items to attach to the email
            if (String.isNotBlank(request.entityAttachments)) {
                oSingleEmailMessage.setEntityAttachments(getStringListFromCommaString(request.entityAttachments));
            }

            // Must be set if template was set!
            oSingleEmailMessage.setTargetObjectId(request.targetObjectId);

            // For further merge fields
            oSingleEmailMessage.setWhatId(request.whatId);

            // If targetObjectId is defined
            if (request.targetObjectId != null) {
                oSingleEmailMessage.setSaveAsActivity(forceBoolean(request.saveAsActivity)); // default true
            }

            /*
            Set<Id> lsetSObjectsToRelate = new Set<Id>();

            if (String.isNotBlank(request.furtherSObjectIdsToRelateActivityTo)) {

                List<String> listFurtherSObjectIdsToRelateActivityTo = getStringListFromCommaString(request.furtherSObjectIdsToRelateActivityTo);

                for (String sSObjectId : listFurtherSObjectIdsToRelateActivityTo) {

                    try {
                        System.debug('Relate also to "' + Id.valueOf(sSObjectId).getSobjectType() + '" ' + sSObjectId);
                        lsetSObjectsToRelate.add(Id.valueOf(sSObjectId));
                    }
                    catch (Exception e) {
                        System.debug(DEBUG_HERE + sSObjectId + ' is not a valid ID to relate activity to');
                    }
                }
            }
            */

            List<Messaging.SendEmailResult> listSendResult = Messaging.sendEmail(new List<Messaging.SingleEmailMessage> {
                oSingleEmailMessage
            });

            System.debug(DEBUG_HERE + 'Messaging.sendEmail result: ' + listSendResult);

            if (!listSendResult.isEmpty() && listSendResult.get(0).isSuccess()) {

                oSendEmailActionResult.sent = true;
                // One task can only have ONE TaskRelation to another object!
                // FIELD_INTEGRITY_EXCEPTION: You can only add up to one WHAT relation
                // Only up to 50 Contacts or 1 Lead can be related to a task
                //if (!lsetSObjectsToRelate.isEmpty()) {}
                oSendEmailActionResult.resultMessage = 'SENT - ' + System.now();
            }
        }
        catch (Exception e) {
            System.debug(DEBUG_HERE + 'Exception: ' + e.getMessage() + ' (' + e.getStackTraceString() + ')');
            oSendEmailActionResult.resultMessage = 'ERROR - ' + System.now() + ' - ' + e.getMessage() + ': ' + e.getStackTraceString();
        }

        return oSendEmailActionResult;
    }

    /**
     * Splits a comma separated list into a string list
     *
     * @param stringToExplode
     *
     * @return
     */
    private static List<String> getStringListFromCommaString(String stringToExplode) {

        if (String.isNotBlank(stringToExplode)) {
            return stringToExplode.replaceAll('\\s', '').replaceAll(',{2,}', ',').split(',');
        }

        return new List<String>();
    }

    /**
     * Check if BCC compliance is enabled
     *
     * @return
     */
    @TestVisible
    private static Boolean isComplianceBccEnabled() {

        Boolean bccComplianceEnabled;
        Messaging.SingleEmailMessage oEmailMessage = new Messaging.SingleEmailMessage();

        oEmailMessage.bccSender = true;

        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{oEmailMessage});
        }
        catch (EmailException e) {
            bccComplianceEnabled = e.getDmlType(0) == StatusCode.BCC_NOT_ALLOWED_IF_BCC_COMPLIANCE_ENABLED;
        }

        return bccComplianceEnabled;
    }

    /**
     * Force a boolean value even if null
     *
     * @param valueToForce
     *
     * @return
     */
    private static Boolean forceBoolean(Boolean valueToForce) {
        return valueToForce != null ? valueToForce : false;
    }

    /**
     * Arguments for invocable
     */
    public class InvocableEmailSenderRequest {

        @InvocableVariable(Label='Org wide sender address' Required=false)
        public String orgWideFromEmail;

        @InvocableVariable(Label='Recipient addresses (comma separated)' Required=true)
        public String toAddress;

        @InvocableVariable (Label='CC addresses (comma separated)' Required=false)
        public String ccAddresses;

        @InvocableVariable (Label='BCC addresses (comma separated)' Required=false)
        public String bccAddresses;

        @InvocableVariable (Label='Attachment IDs (comma separated)' Required=false Description='IDs of Document, ContentVersion, or Attachment items to attach to the email')
        public String entityAttachments;

        @InvocableVariable (Label='HTML Body' Required=false Description='Define this if no template ID was given')
        public String htmlBody;

        @InvocableVariable (Label='Text Body' Required=false Description='Define this if no template ID was given')
        public String textBody;

        @InvocableVariable (Label='Subject' Required=false Description='If no template ID was given')
        public String subject;

        @InvocableVariable (Label='Contact, Lead or User ID (the "who")' Required=false Description='Required if using a template, optional otherwise. The ID of the Contact, Lead, or User to which the email will be sent. The ID you specify sets the context and ensures that merge fields in the template contain the correct data.')
        public Id targetObjectId;

        @InvocableVariable (Label='API Name of template' Required=false)
        public String apiTemplateName;

        @InvocableVariable (Label='Object to relate email to (the "what")' Required=false Description='If you specify a contact for the "Target Object ID" field, you can specify an optional whatId as well. This helps to further ensure that merge fields in the template contain the correct data.')
        public Id whatId;

        @InvocableVariable (Label='Save as activity' Required=false)
        public Boolean saveAsActivity = true;

        @InvocableVariable (Label='Treat bodies as template' Required=false)
        public Boolean treatBodiesAsTemplate = false;

        @InvocableVariable (Label='Field to set on success' Required=false Description='Field value goes into JSON format')
        public String fieldOnObjectToSetOnSuccess;

        @InvocableVariable (Label='Field for sent result string' Required=false Description='Field for the sent result on the "What" object to set result to')
        public String fieldOnObjectToSetResultStringTo;

        //@InvocableVariable (Label='Further Object IDs for relation (comma separated)' Required=false)
        //public String furtherSObjectIdsToRelateActivityTo;
    }

    /**
     * Result
     */
    public class InvocableEmailSenderResult {
        @InvocableVariable
        public Boolean sent;
        public String resultMessage;
    }

    public class InvocableEmailSenderException extends Exception {}
}