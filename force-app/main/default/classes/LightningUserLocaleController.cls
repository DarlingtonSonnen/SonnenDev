public class LightningUserLocaleController {

    @AuraEnabled
    public STATIC string getUserLocale() {
        return UserInfo.getLocale();
    }
}