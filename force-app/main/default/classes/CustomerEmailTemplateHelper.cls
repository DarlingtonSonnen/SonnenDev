public class CustomerEmailTemplateHelper {
    
    public static Id findEmailTemplate(String languageCode, String countryCode, String templateCode) {
        Map<String, Id> templatesByNameCode = new Map<String, Id>();
        
        String nameSearch = '%' + templateCode + '%';
        for(EmailTemplate template : [SELECT Name FROM EmailTemplate WHERE Name like :nameSearch]) {
            templatesByNameCode.put(getTemplateStart(template.Name, templateCode), template.Id);
        }
        System.debug(templatesByNameCode);
        
        System.debug(languageCode + countryCode);
        if(String.isNotBlank(countryCode) && String.isNotBlank(languageCode)) {
            String key = (languageCode + '-' + countryCode + templateCode).toLowerCase();
            if(templatesByNameCode.containsKey(key)) {
                return templatesByNameCode.get(key);
            }
        }
        
        if(String.isNotBlank(countryCode)) {
            String key = (countryCode + templateCode).toLowerCase();
            if(templatesByNameCode.containsKey(key)) {
                return templatesByNameCode.get(key);
            }
        }
        
        return null;
    }
    
    public static String getTemplateStart(String templateName, String templateCode) {
        List<String> templateParts = templateName.toLowerCase().split('_');
        String templateCodeLower = templateCode.toLowerCase();   
        
        String templateStart = templateParts.get(0);     
        if(templateStart != templateCodeLower && templateParts.size() > 1) {
            return templateStart + templateParts.get(1);
        } else {
            return templateStart;
        }
    }

}