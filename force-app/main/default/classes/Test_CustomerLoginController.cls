@isTest
public class Test_CustomerLoginController {

    @isTest
    public static void canCallLogin() {
        CustomLoginController ctr = new CustomLoginController();
        ctr.login();
        ctr.forwardToCustomAuthPage();
    }

}