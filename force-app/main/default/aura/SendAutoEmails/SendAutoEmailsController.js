/**
 * Created by m.muchow on 29.01.2019.
 */
({
    doInit : function(cmp, event, helper) {
        helper.createTemplateList(cmp, event);
        helper.onChangeCustMetaMap(cmp, event);
    },
    onChangeHandler : function(cmp, event, helper) {
        helper.onChangeOptions(cmp, event);
    },
    sendEmailClick : function(cmp, event, helper) {
        helper.sendEmailHelper(cmp, event);
    },
    clearClick : function(cmp, event, helper) {
        helper.clearHelper(cmp, event);
    }
})