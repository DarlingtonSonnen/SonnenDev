/**
 * Created by m.muchow on 29.08.2019.
 */

public with sharing class EscalateCaseController {
    @AuraEnabled
    public static Boolean getUserPermission(Id userId) {
        Boolean hasPermission = false;
        Set<Id> permissionAssignmentIdSet = new Set<Id>();
        Id permissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Case_Escalation_Manager'].Id;
        for (PermissionSetAssignment perSetAssignment : [SELECT AssigneeId FROM PermissionSetAssignment WHERE PermissionSetId =: permissionSetId]) {
            permissionAssignmentIdSet.add(perSetAssignment.AssigneeId);
        }
        if (permissionAssignmentIdSet.contains(userId)) {
            hasPermission = true;
        }
        return hasPermission;
    }
}