/**
 * This Batch Job deletes records of a sObject. The records are selected by a sObject API name and an optional
 * where clause. 
 *
 * @status 		Not functional
 * 
 * @version 	2016-06-14  	kevin.kolditz@die-interaktiven.de 	initial version
 */
global without sharing class RecordDeleteBatch implements Database.Batchable<sObject> {
	
	/** API Name of related sObject for dynamic query e.g. SCRM_Node__c */
	global String sObjectAPIName { get; set; }
	
	/** additional filtering for query */
	global String whereCondition { get; set; }
	
	global RecordDeleteBatch(String sObjectAPIName) {

		this.sObjectAPIName 	= sObjectAPIName;
		this.whereCondition 	= null;
	}	

	global RecordDeleteBatch(String sObjectAPIName, String whereCondition) {

		this.sObjectAPIName 	= sObjectAPIName;
		this.whereCondition 	= whereCondition;
	}
	
	/** START method */
	global Database.QueryLocator start(Database.BatchableContext BC) {

		String query = 'SELECT Id FROM ' + this.sObjectAPIName;
        
		if (this.whereCondition != null) {

			query += ' WHERE ' + this.whereCondition;
		}

		if (Test.isRunningTest()) {
			query += ' limit 10';
		}

		System.debug('Batch Job Query:  ' + query);

		return Database.getQueryLocator(query);
	}
	
	/** EXECUTE method */
	global void execute(Database.BatchableContext BC, List<sObject> scope) {
		try {
			
			delete scope;
		} catch (Exception e) {
			
			System.debug('Batch Job Exception: ' + e.getMessage()); 
		}
	}
	
	/** FINISH method */
	global void finish(Database.BatchableContext BC) {
		
		System.debug('Batch Job Finished'); 
	}
	
}