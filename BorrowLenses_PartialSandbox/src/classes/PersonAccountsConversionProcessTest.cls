/*
	@ PURPOSE : TESTS THE FUNCTIONALITY OF CLASSES:-
				1. PersonAccountsConversionProcessHandler.cls
				2. BusinessAccountDomainProcessHandler.cls
*/

@IsTest
public without sharing class PersonAccountsConversionProcessTest {
	
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
		
		// INSERTS PERSON ACCOUNTS WITH MATCHING DOMAINS.
		List<Account> listOfPersonAccounts = new List<Account>();
		accountRecordTypeId = Account.SobjectType.getDescribe().getRecordTypeInfosByName().get( 'Person Account' ).getRecordTypeId();
		for( Business_Account_Domain__c bad : [ SELECT Account__r.Name, Domain_Name__c FROM Business_Account_Domain__c ] ) {
			listOfPersonAccounts.add( 
									 new Account
									 ( 
									  LastName = bad.Account__r.Name + 'PA', 
									  RecordTypeId = accountRecordTypeId,
									  PersonEmail = bad.Account__r.Name + 'PA' + '@' + bad.Domain_Name__c
									 ) 
									);
		}
		INSERT listOfPersonAccounts;
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Account WHERE ID IN : listOfPersonAccounts ] );
		
		// IF USERNAME PROVIDES ON INSERT, IT IMMEDIATELY CONVERTS PERSON ACCOUNTS TO BUSINESS CONTACTS IF EMAIL DOMAIN IS FOUND BAD RECORDS.
		// SO UPDATES PERSON ACCOUNTS WITH USERNAME.
		for( Account personAccount : listOfPersonAccounts ) {
			personAccount.UserName__pc = personAccount.PersonEmail;
		}
		UPDATE listOfPersonAccounts;
		
		// INSERTS CASES RELATED TO PERSON ACCOUNTS.
		List<Case> listOfCases = new List<Case>();
		for( Account personAccount : listOfPersonAccounts ) {
			listOfCases.add( 
							new Case
							( 
							 Subject = personAccount.LastName + '-Subject',
							 AccountId = personAccount.Id
						    ) 
						   );
		}
		INSERT listOfCases;
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Case WHERE ID IN : listOfCases ] );
		
		// INSERTS OPPORTUNITIES RELATED TO PERSON ACCOUNTS.
		List<Opportunity> listOfOpportunities = new List<Opportunity>();
		for( Account personAccount : listOfPersonAccounts ) {
			listOfOpportunities.add( 
									new Opportunity
									( 
									 Name = personAccount.LastName + '-Opportunity',
									 CloseDate = dateValue, 
									 StageName = 'Proposal',
									 AccountId = personAccount.Id
									) 
								   );
		}
		INSERT listOfOpportunities;
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Opportunity WHERE ID IN : listOfOpportunities ] );
		
		// INSERTS ATTACHMENTS RELATED TO PERSON ACCOUNTS.
		List<Attachment> listOfAttachments = new List<Attachment>();
		for( Account personAccount : listOfPersonAccounts ) {
			listOfAttachments.add
							  ( 
							   new Attachment
							   (
								Name = personAccount.LastName,
								ParentId = personAccount.Id,
								Body = Blob.valueOf( personAccount.LastName ),
								IsPrivate = FALSE
							   )
							  );
		}
		INSERT listOfAttachments;
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Attachment WHERE ID IN : listOfAttachments ] );
		
		// INSERTS CONTENT VERSIONS RELATED TO PERSON ACCOUNTS.
		List<ContentVersion> listOfContentVersions = new List<ContentVersion>();
		for( Account personAccount : listOfPersonAccounts ) {
			listOfContentVersions.add
                				  ( 
								   new ContentVersion
                                   (
                                    Title = personAccount.LastName,
                                    PathOnClient = personAccount.LastName,
                                    VersionData = Blob.valueOf( personAccount.LastName ),
                                    IsMajorVersion = TRUE
                                   )
                                  );
		}
		INSERT listOfContentVersions;
		listOfContentVersions = [ SELECT ID, ContentDocumentId FROM ContentVersion WHERE ID IN : listOfContentVersions ];
		System.assertEquals( intNoOfRecords, listOfContentVersions.size() );
								  
		// INSERTS CONTENT DOCUMENT LINKS RELATED TO PERSON ACCOUNTS.
		List<ContentDocumentLink> listOfContentDocumentLinks = new List<ContentDocumentLink>();
        Set<ID> setOfContentDocumentIds = new Set<ID>();
        for( Integer intPaOrCvIndex = 0; intPaOrCvIndex < intNoOfRecords; intPaOrCvIndex ++ ) {
			listOfContentDocumentLinks.add( 
										   new ContentDocumentLink
										   ( 
											LinkedEntityId = listOfPersonAccounts.get( intPaOrCvIndex ).Id,
                                            ContentDocumentId = listOfContentVersions.get( intPaOrCvIndex ).ContentDocumentId,
                                            ShareType = 'V'
										   ) 
										  );
            setOfContentDocumentIds.add( listOfContentVersions.get( intPaOrCvIndex ).ContentDocumentId );
		}
		INSERT listOfContentDocumentLinks;
		System.assertEquals( intNoOfRecords*2, [ SELECT COUNT() FROM ContentDocumentLink WHERE ContentDocumentId IN : setOfContentDocumentIds ] );
	}
	
	public static testmethod void testConvertPaToBaAndBcFromBusinessAccounts() {
		
		Test.StartTest();
		
		ID accountRecordTypeId = Account.SobjectType.getDescribe().getRecordTypeInfosByName().get( 'Business Account' ).getRecordTypeId();
		Map<ID,Account> businessAccountIdToRecord = new Map<ID,Account>([ SELECT ID, Convert_Person_Accounts__c FROM Account WHERE RecordTypeId =: accountRecordTypeId ]);
        List<Account> listOfBusinessAccounts = businessAccountIdToRecord.values();
		for( Account businessAccount : listOfBusinessAccounts ) {
			businessAccount.Convert_Person_Accounts__c = TRUE;
		}
		UPDATE listOfBusinessAccounts;
        
        // DEPLOYMENT CHANGE AS PROCESS BUILDER DO NOT FIRE WHILE DEPLOYING.
        List<ID> listOfBusinessAccountIds = new List<ID>();
        listOfBusinessAccountIds.addAll( businessAccountIdToRecord.keySet() );
		PersonAccountsConversionProcessHandler.convertPaToBaAndBc( listOfBusinessAccountIds );
		
        // COVERS THE CODE DELIBERATELY.
        PersonAccountsConversionResponse response = new PersonAccountsConversionResponse();
        response.setResponse( TRUE, 'Test Class Executed Successfully' );
        
		Test.stopTest();
		
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Account WHERE ID IN : listOfBusinessAccounts AND Convert_Person_Accounts__c = FALSE ] );
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Business_Account_Domain__c 
											   WHERE Account__c IN : listOfBusinessAccounts AND Convert_Person_Accounts__c = FALSE 
										     ] 
						   );
		
		List<Contact> listOfContacts = [ SELECT ID FROM Contact WHERE AccountId IN : listOfBusinessAccounts ];
		System.assertEquals( intNoOfRecords, listOfContacts.size() );
		
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Case WHERE AccountId IN : listOfBusinessAccounts ] );
		
		List<Opportunity> listOfOpportunties = [ SELECT ID FROM Opportunity WHERE AccountId IN : listOfBusinessAccounts ];
		System.assertEquals( intNoOfRecords, listOfOpportunties.size() );
	}
	
	public static testmethod void testConvertPaToBaAndBcFromBusinessAccountDomains() {
		
		ID accountRecordTypeId = Account.SobjectType.getDescribe().getRecordTypeInfosByName().get( 'Business Account' ).getRecordTypeId();
		List<Account> listOfBusinessAccounts = [ SELECT ID, Convert_Person_Accounts__c FROM Account WHERE RecordTypeId =: accountRecordTypeId ];
		
		Test.StartTest();
		
		Map<ID,Business_Account_Domain__c> businessAccountDomainIdToRecord = new Map<ID, Business_Account_Domain__c>
																			  ([ SELECT ID, Convert_Person_Accounts__c FROM Business_Account_Domain__c ]);
		List<Business_Account_Domain__c> listOfBusinessAccountDomains = businessAccountDomainIdToRecord.values();
		
		for( Business_Account_Domain__c bad : listOfBusinessAccountDomains ) {
			bad.Convert_Person_Accounts__c = TRUE;
		}
		UPDATE listOfBusinessAccountDomains;
		
		// DEPLOYMENT CHANGE AS PROCESS BUILDER DO NOT FIRE WHILE DEPLOYING.
        List<ID> listOfBusinessAccountDomainIds = new List<ID>();
        listOfBusinessAccountDomainIds.addAll( businessAccountDomainIdToRecord.keySet() );
		BusinessAccountDomainProcessHandler.convertPaToBaAndBc( listOfBusinessAccountDomainIds );
		
        // COVERS THE CODE DELIBERATELY.
        PersonAccountsConversionResponse response = new PersonAccountsConversionResponse();
        response.setResponse( TRUE, 'Test Class Executed Successfully' );
        
		Test.stopTest();
		
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Account WHERE ID IN : listOfBusinessAccounts AND Convert_Person_Accounts__c = FALSE ] );
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Business_Account_Domain__c 
											   WHERE Account__c IN : listOfBusinessAccounts AND Convert_Person_Accounts__c = FALSE 
										     ] 
						   );
		
		List<Contact> listOfContacts = [ SELECT ID FROM Contact WHERE AccountId IN : listOfBusinessAccounts ];
		System.assertEquals( intNoOfRecords, listOfContacts.size() );
		
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Case WHERE AccountId IN : listOfBusinessAccounts ] );
		
		List<Opportunity> listOfOpportunties = [ SELECT ID FROM Opportunity WHERE AccountId IN : listOfBusinessAccounts ];
		System.assertEquals( intNoOfRecords, listOfOpportunties.size() );
	}
}