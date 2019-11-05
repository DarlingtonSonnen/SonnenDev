/*
 * Created by Bartosz Jarmolinski
 * Helper class for DuplicateCheckHandlerv3
 *
 * * Version 2.0 - 18/10/2018 by Bartosz
 * - replaced constructor now takes Duplicate Check Object as argument instead of string parameters
 * - added method extractStreetNum(String street)
 * - removed condition if(numberToCheck != numericOutput) - account street can match the original street even if numbers are not the same
 * - added addition 1 point to matchingCount variable if street numbers are the same
 * 
 * * 04/07/2018 by Bartosz Jarmoliski
 * - removed System.debug in line 131
 * 
 * 
 * * v1.1 created on 14/05/2018
 * - added overloaded method FindBestAccountID(List<Account>, Map<Id, Integer>) - the latter argument is map id account id and count of related contracts
*/

public with sharing class DuplicateCheck {

	private String email;
	private String name;
	private String firstName;
	private String lastName;
	private String postCode;
	private String country;
	private String street;
	private String streetNum;
	private String city;
	private String company;

	public DuplicateCheck(DuplicateCheckObject dco) {
		this.email = dco.email;
		this.firstName = dco.firstName;
		this.lastName = dco.lastName;
		this.postCode = dco.postCode;
		this.country = dco.countryCode;
		this.street = dco.street;
		this.streetNum = dco.streetNum;
		this.city = dco.city;
		this.company = dco.company;
		this.name = dco.firstName + ' ' + dco.lastName;
	}

	public Id FindBestAccountID(List<Account> matchingAccounts, Map<Id,Integer> contractCountMap) {
		// the method  returns one account id based on additional match criteria
		Set<Id> accountIdSet = new Set<Id>(); // IDs of matching accounts
		Id recommended;

        for (Account a : matchingAccounts) {
            if (contractCountMap.get(a.Id) > 0 && recommended == NULL) {
                recommended = a.Id;
            }
        }

		// if no account with contract check for the exact match in address
		if (recommended == NULL) {
			recommended = MatchingStreet(street, streetNum, matchingAccounts);
			if (recommended == NULL) {
				recommended = matchingAccounts[0].Id;
			}
		}
		return recommended;
	}

	public Id MatchingStreet (String billingStreet, String streetNumber,List<Account> foundAccounts) {

		Decimal matchingRatio;  // used within loop in the logic
		Decimal finalMatchingRatio = 0;  // final value after the loop is over for the specific account
		Id recommended; // account Id with the best finalMatchingRatio
		String numericOutput; // street number

		// assign/extract the number from values passed to the method
		Pattern p = Pattern.compile('[^0-9]');
		if (streetNumber == NULL) {
			//numericOutput = p.matcher(billingStreet).replaceAll('');
			numericOutput = extractStreetNum(billingStreet);
			System.debug('numeric numericOutput: '+ numericOutput);
		}
		else {
			numericOutput = streetNumber;
		}

		// match the street
		// create pattern which will extract all letter characters from the street strings
		Pattern p2 = Pattern.compile('[^a-zA-Z .]');
		String textOutput = p2.matcher(billingStreet).replaceAll('');
		System.debug('text output: '+ textOutput);
		List<String>  textOutputArray = textOutput.split('');

		// create map with account as key and matching ratio as as value
		// if number matches, check which string has the best matching ratio
		for (Account a : foundAccounts) {

			String numberToCheck;
			String textToCheck;
			// extract street number from the billing street field of the account
			if (a.BillingStreet != NULL) {
				numberToCheck = extractStreetNum(a.BillingStreet);
				//extract street name from the billing street of the account
				textToCheck = p2.matcher(a.BillingStreet).replaceAll('');
				System.debug(numberToCheck);
				System.debug(textToCheck);
			}

			Decimal matchingCount = 0; // count of matching characters
			// split string to individual character

			List<String> textToCheckArray = textToCheck.split('');
			System.debug(textToCheckArray);
			for(Integer i=0; i < textOutputArray.size(); i++) {

				if (i < textToCheckArray.size() && textToCheckArray[i] == textOutputArray[i]) {
					matchingCount = matchingCount + 1; // add 1 to matchingCount variable any time a letter in the account street matches the original street
				}
			}
			// add 1 to matching count if street numbers are the same
			if (numberToCheck == numericOutput) {
				matchingCount = matchingCount + 1;
			}
			System.debug(textOutputArray.size());
			matchingRatio = matchingCount / (Decimal) textOutputArray.size();
			Decimal matchingRatioRounded = matchingRatio.setScale(2);
			//matchingStreetMap.put(a.Id, matchingRatioRounded);

			if (matchingRatio > finalMatchingRatio) {
				finalMatchingRatio = matchingRatio;
				recommended = a.Id;
			}
		}
		//return matchingStreetMap;
		return recommended;
	}

	private String extractStreetNum(String street) {
		// the method extracts street number from the street
		String streetNum;
		Pattern p = Pattern.compile('[^0-9]');
		String output = p.matcher(street).replaceAll(' ');
		List<String> outputList = output.split(' ');
		for (String s : outputList) {
			if (s.isNumeric()) {
				streetNum = s;
				// break the loop as soon as the first number is found - this should be the street number
				break;
			}
		}
		System.debug(streetNum);

		return streetNum;
	}
}

//# equal Email address
//# equal FistName and LastName 
//# BillingAddress