/**
 * Created by m.muchow on 11.09.2018.
 */

public class certificationExtension {
    public String trainConId {get; set;}
    public Date endDate {get; set;}
    public certificationExtension(ApexPages.StandardController controller) {
        Id conId;
        Id trainId;
        TrainingAttendance__c trainCon = (TrainingAttendance__c)controller.getRecord();
        trainConId = trainCon.Id;
        TrainingAttendance__c con = [SELECT Contact__c FROM TrainingAttendance__c WHERE Id =: trainConId];
        conId = con.Contact__c;
        TrainingAttendance__c train = [SELECT Training__c FROM TrainingAttendance__c WHERE Id =: trainConId];
        trainId = train.Training__c;
        Certificate__c certEndDate = [SELECT EndDate__c FROM Certificate__c WHERE Contact__c =: conId AND Training__c =: trainId];
        endDate = certEndDate.EndDate__c;
    }
}