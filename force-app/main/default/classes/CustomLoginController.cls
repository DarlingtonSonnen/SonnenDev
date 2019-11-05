global with sharing class CustomLoginController {
    
    global String username{get;set;}
    global String password{get;set;}
    public String startURL {get;set;}
    public String language {get;set;}
    
    global CustomLoginController () {
        startURL = System.currentPageReference().getParameters().get('startURL');
        language = System.currentPageReference().getParameters().get('language');
    }
    
    global PageReference forwardToCustomAuthPage() {
        return new PageReference( '/CustomerLogin');
    }
    
    global PageReference login() {
        return Site.login(username + '.sonnen', password, startURL);
    }

}