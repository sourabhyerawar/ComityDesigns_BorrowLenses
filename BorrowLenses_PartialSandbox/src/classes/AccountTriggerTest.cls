/*
	@ PURPOSE : TESTS THE FUNCTIONALITY OF TRIGGER AccountTrigger.
*/

@IsTest
public without sharing class AccountTriggerTest {
	
	private static final Integer intNoOfRecords = 10;
	
	@TestSetup static void insertTestData() {
		
		ID accountRecordTypeId;
		Date dateValue = Date.today();
		
		// INSERTS BUSINESS ACCOUNTS.
		List<Account> listOfBusinessAccounts = new List<Account>();
		accountRecordTypeId = Account.SobjectType.getDescribe().getRecordTypeInfosByName().get( 'Business Account' ).getRecordTypeId();
		for( Integer intBusinessAccountIndex = 0; intBusinessAccountIndex < intNoOfRecords; intBusinessAccountIndex ++ ) {
			listOfBusinessAccounts.add( 
									   new Account
									   ( 
									    Name = 'BorrowLensesTest' + intBusinessAccountIndex, 
										RecordTypeId = accountRecordTypeId, 
										Parent_Domain__c = 'BorrowLensesTest' + intBusinessAccountIndex + '.com',
										Convert_Person_Accounts__c = FALSE
									   ) 
									  );
		}
        INSERT listOfBusinessAccounts;
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Account WHERE ID IN : listOfBusinessAccounts ] );
		
		// VERIFIES AUTO INSERTION OF BUSINESS ACCOUNT DOMAINS.
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Business_Account_Domain__c 
											   WHERE Account__c IN : listOfBusinessAccounts AND Domain_Name__c != NULL 
										     ] 
						   );
		
		// VERIFIES AUTO INSERTION OF ENTITLEMENTS.
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Entitlement 
											   WHERE AccountId IN : listOfBusinessAccounts AND StartDate <: dateValue AND Status = 'Active' 
										     ] 
						   );
						   
		// INSERTS MORE BUSINESS ACCOUNT DOMAINS.
		List<Business_Account_Domain__c> listOfMoreBusinessAccountDomains = new List<Business_Account_Domain__c>();
		Integer intExtraBadRecords = 999;
		for( Account recordBusinessAccount : listOfBusinessAccounts ) {
			for( Integer intBADIndex = 989; intBADIndex < intExtraBadRecords; intBADIndex ++ ) {
				listOfMoreBusinessAccountDomains.add
												 ( 
												  new Business_Account_Domain__c
												  (
												   Account__c = recordBusinessAccount.Id,
												   Domain_Name__c = recordBusinessAccount.Name + intBADIndex + + '.com'
												  )
											     );
			}
		}
		INSERT listOfMoreBusinessAccountDomains;
		System.assertEquals( listOfMoreBusinessAccountDomains.size(), 
                            [ SELECT COUNT() FROM Business_Account_Domain__c 
                              WHERE ID IN : listOfMoreBusinessAccountDomains 
                            ] 
						   );
	}
	
	public static testmethod void successTestConvertPaToBaAndBc() {
		
		// INSERTS PERSON ACCOUNTS WITH MATCHING DOMAINS.
		List<Account> listOfPersonAccounts = new List<Account>();
		ID accountRecordTypeId = Account.SobjectType.getDescribe().getRecordTypeInfosByName().get( 'Person Account' ).getRecordTypeId();
		List<Business_Account_Domain__c> listOfBusinessAccountDomains = [ SELECT Account__r.Name, Domain_Name__c FROM Business_Account_Domain__c ];
		
		Test.StartTest();
		
		for( Business_Account_Domain__c bad : listOfBusinessAccountDomains ) {
			listOfPersonAccounts.add( 
									 new Account
									 ( 
									  LastName = bad.Account__r.Name + 'PA', 
									  RecordTypeId = accountRecordTypeId,
									  PersonEmail = bad.Account__r.Name + 'PA' + '@' + bad.Domain_Name__c,
									  UserName__pc = bad.Account__r.Name + 'PA' + '@' + bad.Domain_Name__c
									 ) 
									);
		}
		INSERT listOfPersonAccounts;
		
		Test.stopTest();
		
		System.assertEquals( 0, [ SELECT COUNT() FROM Account WHERE ID IN : listOfPersonAccounts ] );
		System.assertEquals( listOfPersonAccounts.size(), [ SELECT COUNT() FROM Contact WHERE Account.RecordType.Name = 'Business Account' ] );
	}
}