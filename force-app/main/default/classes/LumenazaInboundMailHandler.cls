/**
 * LumenazaInboundMailHandler
 *
 * @version     2018-04-12   marko@die-interaktiven.de      SOBCRM-1164 Implemented configurable inbound delay
 * @version     2018-05-23   polina.drobot@codeswat.com     SOBCRM-1194 added defining contract by Contract Number
 * @version     2018-05-28   polina.drobot@codeswat.com     SOBCRM-1208 added choosing Template according to Contract Type
 *                                                          fixed choosing Template when Subject is covered by a shorter regex
 * @version     2018-06-15   alexey.yamaev@codeswat.com     SOBCRM-1209 added verification for existing template Id
 *
 * @see LumenazaTest
 */
public class LumenazaInboundMailHandler implements Messaging.InboundEmailHandler {

    private List<LumenazaEmailTemplates__c> templates;

    public static final String lumenazaContractIdRegex = '\\b([P|C][0-9]+-[0-9]+)\\b'; // since SOBCRM-363
    public static final String lumenazaContractNumberRegex = '\\b([0-9]{3,})\\b'; // since SOBCRM-1194
    public static final String testContractId = 'P16000001-1';

    private Decimal inboundDelay = 0;

    /**
     * Constructor
     */
    public LumenazaInboundMailHandler() {

        // Get all email templates
        this.templates = LumenazaEmailTemplates__c.getall().values();

        if (this.templates == null) {
            throw new LumenazaInboundMailHandlerException('LumenazaInboundMailHandler - No LumenazaEmailTemplates found');
        }

        if (LumenazaApi.settingsName != null) {

            LumenazaSettings__c oLumenazaSettings = LumenazaSettings__c.getValues(LumenazaApi.settingsName);

            if (oLumenazaSettings != null
                && oLumenazaSettings.InboundMailHandlerDelayMilliseconds__c != null
                && oLumenazaSettings.InboundMailHandlerDelayMilliseconds__c <= 8000
                && oLumenazaSettings.InboundMailHandlerDelayMilliseconds__c >= 0
                ) {
                this.inboundDelay = oLumenazaSettings.InboundMailHandlerDelayMilliseconds__c;
                System.debug('LumenazaInboundMailHandler - Set inbound delay according to configured custom setting: ' + oLumenazaSettings.InboundMailHandlerDelayMilliseconds__c + ' ms');
            }
        }
    }

    /**
     * Implements interface method "handleInboundEmail"
     */
    public Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {

        if (this.inboundDelay > 0) {

            Long fStartingTime = System.now().getTime();

            while (System.now().getTime() - fStartingTime < this.inboundDelay)  {
                // Do nothing until desired delay has passed
            }
        }

		Messaging.InboundEmailResult result = new Messaging.InboundEmailresult();

		System.debug('LumenazaInboundMailHandler - Try to route mail from ' + email.fromAddress + ' with subject "' + email.subject + '"');

        String mailTemplateId;
        String ruleName;
        String mailSenderDisplayName;
        String mailSenderId;

        try {

            Contract contract = findAppropriateContract(email);

            if (contract.ContractingPartyEmail__c == NULL) {
                throw new LumenazaInboundMailHandlerException('LumenazaInboundMailHandler - Contract has no email in ContractingPartyEmail__c');
            }

            LumenazaEmailTemplates__c template = findAppropriateTemplate(email, contract);

            mailTemplateId        = template.EmailTemplateId__c;
            ruleName              = template.InternalName__c;
            mailSenderDisplayName = template.EmailSenderDisplayName__c;
            mailSenderId          = template.EmailSenderId__c;
            List<EmailTemplate> emailTemplates = [SELECT Id FROM EmailTemplate WHERE Id = :mailTemplateId];
            if (emailTemplates.isEmpty()) {
                throw new LumenazaInboundMailHandlerException('Template Id mentioned in custom setting "Lumenaza Email Templates" is wrong');
            }

            String mailTo = contract.ContractingPartyEmail__c;
			System.debug('LumenazaInboundMailHandler - Salesforce Contract ID is "' + contract.Id + '" with email "' + mailTo + '"');

            // Add attachments to contract and activity
        	List<Attachment> attachments = new List<Attachment>();

            if (email.binaryAttachments != NULL && email.binaryAttachments.size() > 0) {

				System.debug('LumenazaInboundMailHandler - Handle ' + email.binaryAttachments.size() + ' attachment(s)');

                for (Messaging.Inboundemail.BinaryAttachment binaryAttachment: email.binaryAttachments) {

                    attachments.add(new Attachment(
                        Name = binaryAttachment.FileName,
                        Body = binaryAttachment.Body,
                        ParentId = contract.Id
                    ));
                    System.debug('LumenazaInboundMailHandler - Add attachment "' + binaryAttachment.fileName + '"');
                }
                if (attachments.size() > 0) {
                    insert attachments;
                }
            }
            else {
				System.debug('LumenazaInboundMailHandler - No attachments found');
            }

            // Create an activity/task
            String subject     = email.subject + ' (-> ' + ruleName + ')';

            String description  = 'EMAIL RULE:\n' + ruleName + '\n\n';
                   description += 'EMAIL TEMPLATE:\n' + this.makeInternalUrlToId(mailTemplateId) + '\n\n';

            if (attachments.size() > 0) {
            	description += 'ATTACHMENT:\n';
                for (Attachment attachment : attachments) {
                	description += attachment.Name + ' (' + this.makeInternalUrlToId(attachment.Id) + ')\n';
                }
            	description += '\n';
            }

            description += 'CONTENT:\n' + email.plainTextBody;

            Task task = new Task(
                Subject      = subject.length() > 255 ? subject.substring(0, 255) : subject,
                Type         = 'Email',
                Description  = description.length() > 32000 ? description.substring(0, 32000) : description,
                WhatId       = contract.Id,
                Status       = 'Completed',
                ActivityDate = System.today()
            );
			insert task;

            this.sendMergeTemplateMailWithoutTargetObject(mailTo, Id.valueOf(mailTemplateId), contract.Id, attachments, mailSenderDisplayName, mailSenderId);
        }
        catch(Exception e) {

            String traceString = e.getStackTraceString();

            Case emailCase = new Case();
            emailCase.subject = 'Error on handling email from ' + email.fromAddress;
			emailCase.description  = e.getMessage() + (e.getCause() != NULL ? ' ' + e.getCause() : '')  + (e.getLineNumber() > 0 ? ' in line #' + e.getLineNumber() : '');
            emailCase.description += '\n\nSubject:\n' + email.subject;
            emailCase.description += '\n\nEmail body:\n' + email.plainTextBody;
            if (traceString.length() > 0) {
				emailCase.description += '\n\nTrace:\n' + traceString;
            }
            insert emailCase;

            // Add attachments (SOBCRM-167)
        	List<Attachment> caseAttachments = new List<Attachment>();

            if (email.binaryAttachments != NULL && email.binaryAttachments.size() > 0) {
                for (Messaging.Inboundemail.BinaryAttachment binaryAttachment: email.binaryAttachments) {
                    caseAttachments.add(new Attachment(
                        Name = binaryAttachment.FileName,
                        Body = binaryAttachment.Body,
                        ParentId = emailCase.Id
                    ));
                }
                if (caseAttachments.size() > 0) {
                    insert caseAttachments;
                }
            }
        }

        return result;
    }

    private Contract findAppropriateContract(Messaging.InboundEmail email) {
        // Search for contract ID and Numbers
        String contractId = '';

        // as the regex for Contract Number is not so unique,
        // we want search by all possible values
        Set<String> contractNumbers = new Set<String>();

        // Try to find the Lumenaza contract ID in
        contractId = this.searchLumenazaContractId(email.subject); // Subject
        if (contractId == '') {
            contractId = this.searchLumenazaContractId(email.plainTextBody); // Text body
            if (contractId == '') {
                contractId = this.searchLumenazaContractId(email.htmlBody); // HTML body
                if (contractId == '') {
                    // Try to find all possible Lumenaza Contract Numbers in
                    contractNumbers.addAll(this.searchLumenazaContractNumbers(email.subject)); // Subject
                    contractNumbers.addAll(this.searchLumenazaContractNumbers(email.plainTextBody)); // Text body
                    contractNumbers.addAll(this.searchLumenazaContractNumbers(email.subject)); // HTML body
                }
            }
        }

        if (contractId == '' && contractNumbers.isEmpty()) {
            throw new LumenazaInboundMailHandlerException('LumenazaInboundMailHandler - Contract ID and Contract Number could not be found');
        }

        if (contractId != '') {
            System.debug('LumenazaInboundMailHandler - Lumenaza Contract ID is "' + contractId + '"');
        } else {
            System.debug('LumenazaInboundMailHandler - Lumenaza Contract Numbers are ' + String.join(new List<String>(contractNumbers), ', '));
        }

        List<Contract> contracts;

        // we can't use single query as in this case we should respect the conditions, it's more problematic
        if (contractId != '') {
            contracts = [
                SELECT Id, Type__c, LumenazaContractId__c, ContractNumber, ContractingPartyEmail__c
                FROM Contract
                WHERE LumenazaContractId__c = :contractId
            ];
        } else {
            contracts = [
                SELECT Id, Type__c, LumenazaContractId__c, ContractNumber, ContractingPartyEmail__c
                FROM Contract
                WHERE ContractNumber IN :contractNumbers
            ];
        }

        if (contracts.isEmpty()) {
            if (contractId != '') {
                throw new LumenazaInboundMailHandlerException('LumenazaInboundMailHandler - Contract with Contract ID "' + contractId + '" not found');
            } else {
                throw new LumenazaInboundMailHandlerException('LumenazaInboundMailHandler - Contract with Contract Numbers ' + String.join(new List<String>(contractNumbers), ', ') + ' not found');
            }
        }

        for (Contract contract : contracts) {
            System.debug('LumenazaInboundMailHandler - Contract found:: ' + contract);
        }

        if (contracts.size() > 1) {
            System.debug('LumenazaInboundMailHandler - We found MULTIPLE contracts, but will work only with the first one:: ' + contracts[0]);
        }

        return contracts[0];
    }

    public LumenazaEmailTemplates__c findAppropriateTemplate(Messaging.InboundEmail email, Contract contract) {
        List<LumenazaEmailTemplateWrapper> matchingTemplates = new List<LumenazaEmailTemplateWrapper>();

        for (LumenazaEmailTemplates__c template : this.templates) {

            Matcher patternMatcher = Pattern.compile(template.EmailSubjectRegex__c).matcher(email.subject);

            if (patternMatcher.matches() && (template.ContractType__c == contract.Type__c || template.ContractType__c == null)) {
                // we collect all matching templates, for futher filtering and choosing the one
                matchingTemplates.add(new LumenazaEmailTemplateWrapper(template));
                System.debug('LumenazaInboundMailHandler - Matching email:: ' + template);
            }
        }

        if (matchingTemplates.isEmpty()) {
            throw new LumenazaInboundMailHandlerException('LumenazaInboundMailHandler - No matching LumenazaEmailTemplates entry found to handle mail');
        }

        if (matchingTemplates.size() > 1) {
            System.debug('LumenazaInboundMailHandler - We found MULTIPLE matching templates, so we will sort them by relevance and take the first one.');

            matchingTemplates.sort();

            System.debug('LumenazaInboundMailHandler - Matching templates after sort:: ');
            for (LumenazaEmailTemplateWrapper templateWrapper : matchingTemplates) {
                System.debug('LumenazaInboundMailHandler - Matching email:: ' + templateWrapper.template);
            }

            System.debug('LumenazaInboundMailHandler - We take this template as the most relevant:: ' + matchingTemplates[0].template);
        }

        return matchingTemplates[0].template;
    }

    /**
     * Search for a Lumenaza contract ID according
     * to the defined lumenazaContractIdRegex
     */
    private String searchLumenazaContractId(String contentToSearchIn) {

        String lumenazaContractId = '';

        if (contentToSearchIn == NULL) {
            return lumenazaContractId;
        }

		System.debug('LumenazaInboundMailHandler - searchLumenazaContractId() Search via regex "' + lumenazaContractIdRegex + ' in: ' + contentToSearchIn);
        Matcher patternMatcher = Pattern.compile(lumenazaContractIdRegex).matcher(contentToSearchIn);

        if (patternMatcher.find() == true) {
            lumenazaContractId = patternMatcher.group(0);
        }

        return lumenazaContractId;
    }

    /**
     * Search for a Lumenaza contract Number according
     * to the defined lumenazaContractNumberRegex
     */
    private List<String> searchLumenazaContractNumbers(String contentToSearchIn) {

        List<String> lumenazaContractNumbers = new List<String>();

        if (contentToSearchIn == NULL) {
            return lumenazaContractNumbers;
        }

        System.debug('LumenazaInboundMailHandler - searchLumenazaContractNumbers() Search via regex "' + lumenazaContractNumberRegex + ' in: ' + contentToSearchIn);
        Matcher patternMatcher = Pattern.compile(lumenazaContractNumberRegex).matcher(contentToSearchIn);

        while (patternMatcher.find()) {
            lumenazaContractNumbers.add(patternMatcher.group(0));
        }

        return lumenazaContractNumbers;
    }

    /**
     * Creates an internal Salesforce URL by an ID
     */
    private String makeInternalUrlToId(String idToLinkTo) {
    	return System.Url.getSalesforceBaseUrl().toExternalForm() + '/' + idToLinkTo;
    }

    /**
     * Sends a merge template mail without having a contact,
     * lead or something as target object
     */
    private void sendMergeTemplateMailWithoutTargetObject(String mailTo, Id templateId, Id whatId, List<Attachment> attachments, String mailSenderDisplayName, String mailSenderId) {

        List<Messaging.SingleEmailMessage> dummyEmailList = new List<Messaging.SingleEmailMessage>();
        Messaging.SingleEmailMessage dummyEmail = new Messaging.SingleEmailMessage();

        Savepoint sp = Database.setSavepoint();

		System.debug('LumenazaInboundMailHandler - sendMergeTemplateMailWithoutTargetObject() Try to send mail to: ' + mailTo);

        try {
            // Create a dummy account and contact
            Datetime now =  Datetime.now();
            String dummyName = 'Dummy ' + now.getTime();

            Account dummyAccount = new Account(Name = dummyName);
            insert dummyAccount;
            Contact dummyContact = new Contact(LastName = dummyName, Email = mailTo, AccountId = dummyAccount.Id);
            insert dummyContact;

            System.debug('LumenazaInboundMailHandler - sendMergeTemplateMailWithoutTargetObject() Created dummy Account: ' + dummyAccount);
            System.debug('LumenazaInboundMailHandler - sendMergeTemplateMailWithoutTargetObject() Created dummy Contact: ' + dummyContact);

            // Construct a dummy email by template and the dummy contact
            dummyEmail.setTemplateId(templateId);
            dummyEmail.setWhatId(whatId);
            dummyEmail.setTargetObjectId(dummyContact.Id);
            dummyEmail.setToAddresses(new List<String>{mailTo});
            dummyEmailList.add(dummyEmail);

            System.debug('LumenazaInboundMailHandler - sendMergeTemplateMailWithoutTargetObject() templateId: ' + templateId + ', whatId: ' + whatId);
            System.debug('LumenazaInboundMailHandler - sendMergeTemplateMailWithoutTargetObject() dummyEmail: ' + dummyEmail);

            // Send the emails in a transaction, then roll it back
            Messaging.sendEmail(dummyEmailList);
        }
        catch (Exception e) {
            // Catch Exception so make sure that rollback is forced!
        	Database.rollback(sp);
            // Throw own exception
            throw new LumenazaInboundMailHandlerException(e);
        }

        Database.rollback(sp);

        // Get "send" rendered mail and create a new Mail by this
        dummyEmail = dummyEmailList.get(0);

        Messaging.SingleEmailMessage emailToSend = new Messaging.SingleEmailMessage();

        //emailToSend.setToAddresses(dummyEmail.getToAddresses());
        emailToSend.setToAddresses(new List<String>{mailTo});
        emailToSend.setPlainTextBody(dummyEmail.getPlainTextBody());
        emailToSend.setHTMLBody(dummyEmail.getHTMLBody());
        emailToSend.setSubject(dummyEmail.getSubject());

        if (mailSenderId != NULL && mailSenderId.length() > 0) {
        	emailToSend.setOrgWideEmailAddressId(mailSenderId);
        }
        else if (mailSenderDisplayName != NULL && mailSenderDisplayName.length() > 0) {
        	emailToSend.setSenderDisplayName(mailSenderDisplayName);
        }

        // Add attachments
        List<Messaging.EmailFileAttachment> emailAttachments = new List<Messaging.EmailFileAttachment>();

        if (attachments.size() > 0) {
            for (Attachment attachment : attachments) {
        		Messaging.EmailFileAttachment emailAttachment = new Messaging.EmailFileAttachment();
                emailAttachment.setBody(attachment.Body);
                emailAttachment.setFileName(attachment.Name);
                emailAttachments.add(emailAttachment);
            }
            emailToSend.setFileAttachments(emailAttachments);
        }

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{emailToSend});
    }

    /**
     * Own exception
     */
   	public class LumenazaInboundMailHandlerException extends Exception {}

    public class LumenazaEmailTemplateWrapper implements Comparable {

        public LumenazaEmailTemplates__c template;

        public LumenazaEmailTemplateWrapper(LumenazaEmailTemplates__c template) {
            this.template = template;
        }

        // we sort templates by 2 things (look SOBCRM-1208):
        // 1) EmailSubjectRegex__c length - to put the longest to the beginning,
        //      (as short regex-es are also covered),
        //      for exaple string "Lieferbestaetigung sonnenFlat C18689811-1" matches both
        //      regexes "Lieferbestaetigung\s+.+" and "Lieferbestaetigung sonnenFlat\s+.+",
        //      BUT we need to take the "Lieferbestaetigung sonnenFlat\s+.+".
        // 2) and ContractType__c - to put the ones with specified ContractType__c to the beginning,
        //      as we need first the template with concrete ContractType__c to be taken,
        //      and only if we don't have it - the template with empty ContractType__c
        public Integer compareTo(Object compareToObj) {
            LumenazaEmailTemplateWrapper cmpToWrapper = (LumenazaEmailTemplateWrapper)compareToObj;

            if (this.template.EmailSubjectRegex__c.length() > cmpToWrapper.template.EmailSubjectRegex__c.length() ||
                (this.template.EmailSubjectRegex__c == cmpToWrapper.template.EmailSubjectRegex__c &&
                 this.template.ContractType__c != null && cmpToWrapper.template.ContractType__c == null)) {
                return -1;
            }
            if (this.template.EmailSubjectRegex__c == cmpToWrapper.template.EmailSubjectRegex__c &&
                this.template.ContractType__c == cmpToWrapper.template.ContractType__c) {
                return 0;
            }
            return 1;
        }
    }
}