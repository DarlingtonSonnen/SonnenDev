/**
 * attendanceListController
 *
 * Controller Extension for the Visualforce Page 'AttendanceList'
 *
 * @see AttendanceList
 * @see attendanceListControllerTest
 *
 * ___ Changelog ___
 * v 1.0 Michael Muchow 2018-03-20
 *
 * @version 1.0
 */
public class attendanceListController {
    public List<TrainingAttendance__c> attList {get;set;}

    public attendanceListController(ApexPages.StandardController setCon) {
        Training__c train = (Training__c) setCon.getRecord();
        attList = [SELECT ID, Name, Contact__r.Salutation, Contact__r.Firstname, Contact__r.Lastname, Account__c, Contact__r.Title, Contact__r.Email, Contact__r.MobilePhone, Contact__r.Phone, Contact__r.MailingStreet, Contact__r.MailingPostalCode, Contact__r.MailingCity, Contact__r.MailingCountryCode, TaxId__c, Status__c From TrainingAttendance__c WHERE Training__c =: train.ID]; 
    } 
}