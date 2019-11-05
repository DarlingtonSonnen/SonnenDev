public class DynamicEmailController {
    
    public DynamicEmailController() {}
    
    public String emailRelatedToId {get; set;}
    public String emailTemplateId {get; set;}
    public Boolean isHtml {get; set;}
    
    private Messaging.SingleEmailMessage renderedEmail {
        get {
            if (renderedEmail==null) {
                renderedEmail = Messaging.renderStoredEmailTemplate(emailTemplateId, '', emailRelatedToId);
            }
            return renderedEmail;
        }
        set;
    }
    
    public String getMergedEmailHtmlBody() {
        return renderedEmail.getHtmlBody();
    }
    
    public String getMergedEmailPlainTextBody() {
        return renderedEmail.getPlainTextBody();
    }
    
    public String getMergedEmailSubject() {
        return renderedEmail.getSubject();
    }
}