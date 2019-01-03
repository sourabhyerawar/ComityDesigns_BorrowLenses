/*
	@ PURPOSE : 1. RECEIVES THE LIST OF ACCOUNT IDs WHOSE 'CONVERT PERSON ACCOUNTS' CHECKBOX FIELD IS MARKED.
				2. FETCHES BUSINESS ACCOUNT DOMAIN RECORDS FROM THESE BUSINESS ACCOUNTS.
				3. FETCHES PERSON ACCOUNTS WHOSE DOMAIN IN EMAIL ADDRESS IS SAME AS THAT OF DOMAIN NAME OF BUSINESS DOMAIN RECORDS.
				4. UPDATES THE RECORD TYPE OF PERSON ACCOUNTS TO BUSINESS ACCOUNT.
				5. PERSON CONTACTS WILL BE UPDATED TO BUSINESS CONTACTS AUTOMATICALLY.
				6. UPDATES ACCOUNT FIELD OF BUSINESS CONTACTS WITH EXISTING BUSINESS ACCOUNT.
				7. REPARENTS THE CASES AND OPPORTUNITIES FROM PERSON ACCOUNTS TO EXISTING BUSINESS ACCOUNT.
				8. CREATES OPPORTUNITY CONTACT ROLES WITH THE COMBINATION OF OPPORTUNITIES AND BUSINESS CONTACTS.
				9. CLONES ATTACHMENTS AND CONTENT DOCUMENT LINKS FROM PERSON ACCOUNTS TO BUSINESS CONTACTS.
				10. REPARENTS THE ENTITLEMENTS FROM PERSON ACCOUNTS TO BUSINESS ACCOUNTS AND UPDATES OTHER FIELDS.
				11. DELETES THE PERSON ACCOUNTS ( WHOSE RECORD TYPE IS JUST UPDATED TO BUSINESS ACCOUNT ).
				12. UPDATES BUSINESS ACCOUNTS WITH 'CONVERT PERSON ACCOUNTS' AS FALSE.
*/
public class PersonAccountsConversionProcessHandler {
	
	/*
		@ PURPOSE : 1. RECEIVES THE LIST OF ACCOUNT IDs WHOSE 'CONVERT PERSON ACCOUNTS' CHECKBOX FIELD IS MARKED.
					2. FETCHES BUSINESS ACCOUNT DOMAIN RECORDS FROM THESE BUSINESS ACCOUNTS.
					3. CONVERTS THE MATCHING PERSON ACCOUNTS.
					4. UPDATES BUSINESS ACCOUNTS WITH 'CONVERT PERSON ACCOUNTS' AS FALSE.
	*/
	@InvocableMethod
	public static void convertPaToBaAndBc( List<ID> listOfBusinessAccountIds ) {
		
		if( listOfBusinessAccountIds != NULL && !listOfBusinessAccountIds.isEmpty() ) {
			List<Business_Account_Domain__c> listOfBusinessAccountDomains = getListOfBusinessAccountDomains( listOfBusinessAccountIds );
			if( !listOfBusinessAccountDomains.isEmpty() ) {
				convertPaToBaAndBc( listOfBusinessAccountDomains );
			}
			updateExistingBusinessAccounts( listOfBusinessAccountIds );
		}
	}
	
	/*
		@ PURPOSE : 1. RECEIVES BUSINESS ACCOUNT DOMAIN RECORDS.
					2. CONVERTS THE MATCHING PERSON ACCOUNTS.
	*/
	public static void convertPaToBaAndBc( List<Business_Account_Domain__c> listOfBusinessAccountDomains ) {
		
		if( listOfBusinessAccountDomains != NULL && !listOfBusinessAccountDomains.isEmpty() ) {
			Map<String,ID> domainNameToBusinessAccountId = getDomainNameToBusinessAccountId( listOfBusinessAccountDomains );
			if( !domainNameToBusinessAccountId.isEmpty() ) {
				List<Account> listOfPersonAccounts = getListOfPersonAccountsFromDomains( domainNameToBusinessAccountId.keySet() );
				if( !listOfPersonAccounts.isEmpty() ) {
					convertPaToBaAndBc( listOfBusinessAccountDomains, domainNameToBusinessAccountId, listOfPersonAccounts );
				}
			}
		}
	}
	
	public static void convertPaToBaAndBc( List<Business_Account_Domain__c> listOfBusinessAccountDomains, 
										   Map<String,ID> domainNameToBusinessAccountId,
										   List<Account> listOfPersonAccounts
	) {
		if( listOfBusinessAccountDomains != NULL && domainNameToBusinessAccountId != NULL && listOfPersonAccounts != NULL ) {
			
			Map<String,List<Account>> domainNameToListOfPersonAccounts = new Map<String,List<Account>>();
			Map<ID,ID> personAccountIdToPersonAccountContactId = new Map<ID,ID>();
			Map<ID,ID> personAccountIdToBusinessAccountId = new Map<ID,ID>();
			
			List<Contact> listOfPersonContactsToUpdate = new List<Contact>();
			List<Entitlement> listOfEntitlementsToReparent = new List<Entitlement>();
			
			Date dateToday = System.today();
			String strEmailDomain;
			ID existingBusinessAccountId;
			
			ID businessAccountRecordTypeId;
			try {
				businessAccountRecordTypeId = Account.SobjectType.getDescribe().getRecordTypeInfosByName().get( 'Business Account' ).getRecordTypeId();
			}
			catch( Exception e ) {
				System.debug( 'Exception While Fetching Business Account Record Type Id:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
			
			if( businessAccountRecordTypeId != NULL ) {
				for( Account recordPersonAccount : listOfPersonAccounts ) {
					
					// DOMAIN NAME WITH LIST OF SIMILAR PERSON ACCOUNTS.
					strEmailDomain = recordPersonAccount.Email_Domain__pc.toLowerCase();
					existingBusinessAccountId = domainNameToBusinessAccountId.get( strEmailDomain );
					
					if( domainNameToListOfPersonAccounts.containsKey( strEmailDomain ) ) {
						domainNameToListOfPersonAccounts.get( strEmailDomain ).add( recordPersonAccount );
					}
					else {
						domainNameToListOfPersonAccounts.put( strEmailDomain, new List<Account>{ recordPersonAccount } );
					}
					
					// PERSON ACCOUNT ID WITH ITS PERSON CONTACT ID.
					personAccountIdToPersonAccountContactId.put( recordPersonAccount.Id, recordPersonAccount.PersonContactId );
					
					// PERSON ACCOUNT ID WITH ITS MATCHING PARENT BUSINESS ACCOUNT ID.
					personAccountIdToBusinessAccountId.put( recordPersonAccount.Id, existingBusinessAccountId );
					
					// UPDATE RECORD TYPE OF PERSON ACCOUNTS TO BUSINESS ACCOUNT.
					recordPersonAccount.RecordTypeId = businessAccountRecordTypeId;
					
					listOfPersonContactsToUpdate.add( new Contact( Id = recordPersonAccount.PersonContactId, AccountId = existingBusinessAccountId ) );
					
					if( !recordPersonAccount.Entitlements.isEmpty() ) {
						for( Entitlement recordEntitlement : recordPersonAccount.Entitlements ) {
							recordEntitlement.AccountId = existingBusinessAccountId;
							recordEntitlement.Re_Parented__c = TRUE;
							recordEntitlement.Name += ' Re-Parented';
							recordEntitlement.EndDate = dateToday;
						}
						listOfEntitlementsToReparent.addAll( recordPersonAccount.Entitlements );
					}
				}
						
				Savepoint beforeConversionPoint = Database.setSavepoint();
				PersonAccountsConversionResponse response;
				try {
					UPDATE listOfPersonAccounts;
					
					UPDATE listOfPersonContactsToUpdate;
					
					UPDATE listOfEntitlementsToReparent;
					
					response = updateRelatedRecordsOfPersonAccounts( personAccountIdToBusinessAccountId, personAccountIdToPersonAccountContactId );
					if( response.isSucceeded ) {
						
						DELETE listOfPersonAccounts;
						
						// UPDATES THE BAD RECORDS WITH CONVERTED DATE/TIME FIELD FOR WHOM AT LEAST ONE PERSON ACCOUNTS WAS MATCHED/FOUND.
						DateTime now = System.now();
						for( Business_Account_Domain__c recordBusinessAccountDomain : listOfBusinessAccountDomains ) {
							if( domainNameToListOfPersonAccounts.containsKey( recordBusinessAccountDomain.Domain_Name__c.toLowerCase() ) ) {
								recordBusinessAccountDomain.Converted_Date_Time__c = now;
							}
						}
						UPDATE listOfBusinessAccountDomains;
					}
					else {
						Database.rollback( beforeConversionPoint );
					}
				}
				catch( Exception e ) {
					Database.rollback( beforeConversionPoint );
				}
				finally {
					System.debug( 'convertPaToBaAndBc-response:-\n' + JSON.serialize( response ) );
				}
			}
		}
	}
	
	/*
		@ PURPOSE : 1. RECEIVES THE LIST OF BUSINESS ACCOUNT DOMAINS.
					2. CREATES A MAP OF DOMAIN NAME WITH ITS BUSINESS ACCOUNT ID.
	*/
	public static Map<String,ID> getDomainNameToBusinessAccountId( List<Business_Account_Domain__c> listOfBusinessAccountDomains ) {
			
		Map<String,ID> domainNameToBusinessAccountId = new Map<String,ID>();
		if( listOfBusinessAccountDomains != NULL && !listOfBusinessAccountDomains.isEmpty() ) {
			for( Business_Account_Domain__c recordBusinessAccountDomain : listOfBusinessAccountDomains ) {
				domainNameToBusinessAccountId.put( recordBusinessAccountDomain.Domain_Name__c.toLowerCase(), recordBusinessAccountDomain.Account__c );
			}
		}
		return domainNameToBusinessAccountId;
	}
	
	/*
		@ PURPOSE : 1. RECEIVES THE LIST OF BUSINESS ACCOUNTS.
					2. FETCHES THE LIST OF BUSINESS ACCOUNT DOMAINS.
	*/
	private static List<Business_Account_Domain__c> getListOfBusinessAccountDomains( List<ID> listOfBusinessAccountIds ) {
		
		List<Business_Account_Domain__c> listOfBusinessAccountDomains = new List<Business_Account_Domain__c>();
		if( listOfBusinessAccountIds != NULL && !listOfBusinessAccountIds.isEmpty() ) {
			try {
				listOfBusinessAccountDomains = [ SELECT ID, Account__c, Converted_Date_Time__c, Convert_Person_Accounts__c, Domain_Name__c
												 FROM Business_Account_Domain__c
												 WHERE 
												 Account__c IN : listOfBusinessAccountIds
													AND
												 Domain_Name__c != NULL
											   ];
			}
			catch( Exception e ) {
				System.debug( 'Exception While Fetching Business Account Domains:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
		}
		return listOfBusinessAccountDomains;
	}
	
	/*
		@ PURPOSE : 1. RECEIVES THE SET OF DOMAIN NAMES FROM BUSINESS ACCOUNT DOMAINS.
					2. FETCHES PERSON ACCOUNTS WITH ENTITLEMENTS WHOSE EMAIL DOMAIN IS MATCHED.
	*/
	private static List<Account> getListOfPersonAccountsFromDomains( Set<String> setOfDomainNames ) {
		
		List<Account> listOfPersonAccounts = new List<Account>();
		if( setOfDomainNames != NULL && !setOfDomainNames.isEmpty() ) {
			try {
				ID personAccountRecordTypeId = Account.SobjectType.getDescribe().getRecordTypeInfosByName().get( 'Person Account' ).getRecordTypeId();
				listOfPersonAccounts = [ SELECT ID, PersonContactId, RecordTypeId, Email_Domain__pc,
									     ( SELECT ID, Name, AccountId, EndDate, Re_Parented__c FROM Entitlements ) 
										 FROM Account
										 WHERE 
										 RecordTypeId =: personAccountRecordTypeId
											AND
										 Email_Domain__pc IN : setOfDomainNames
									   ];
			}
			catch( Exception e ) {
				System.debug( 'Exception While Fetching Person Accounts From Domains:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
		}
		return listOfPersonAccounts;
	}
	
	/*
		@ PURPOSE : 1. RECEIVES A MAP OF PERSON ACCOUNT ID WITH ITS MATCHING BUSINESS ACCOUNT ID.
					2. RECEIVES ALSO A MAP OF PERSON ACCOUNT ID WITH PERSON ACCOUNT'S CONTACT ID.
					3. RE-PARENTS ALL THE RELATED RECORDS OF PERSON ACCOUNTS TO EITHER MATCHING BUSINESS ACCOUNTS OR THEIR CONTACTS.
	*/
	private static PersonAccountsConversionResponse updateRelatedRecordsOfPersonAccounts( Map<ID,ID> personAccountIdToBusinessAccountId, 
																						  Map<ID,ID> personAccountIdToPersonAccountContactId 
	) {
		PersonAccountsConversionResponse response = new PersonAccountsConversionResponse();
		if( personAccountIdToBusinessAccountId != NULL && !personAccountIdToBusinessAccountId.isEmpty() &&
			personAccountIdToPersonAccountContactId != NULL && !personAccountIdToPersonAccountContactId.isEmpty()
		) {
			response = updateCasesToExistingBusinessAccounts( personAccountIdToBusinessAccountId );
			if( response.isSucceeded ) {
				response = updateOpportunitiesToExistingBusinessAccounts( personAccountIdToBusinessAccountId, personAccountIdToPersonAccountContactId );
				if( response.isSucceeded ) {
					response = cloneAttachmentsAndContentDocumentsWithReparenting( personAccountIdToPersonAccountContactId );
				}
			}
		}
		return response;
	}
	
	/*
		@ PURPOSE : 1. RECEIVES A MAP OF PERSON ACCOUNT ID WITH ITS MATCHING BUSINESS ACCOUNT ID.
					2. FETCHES CASES FROM PERSON ACCOUNTS AND RE-PARENTS THEM TO BUSINESS ACCOUNTS.
	*/
	private static PersonAccountsConversionResponse updateCasesToExistingBusinessAccounts( Map<ID,ID> personAccountIdToBusinessAccountId ) {
		
		PersonAccountsConversionResponse response = new PersonAccountsConversionResponse();
		if( personAccountIdToBusinessAccountId != NULL && !personAccountIdToBusinessAccountId.isEmpty() ) {
			try {
				List<Case> listOfCases = [ SELECT ID, AccountId FROM Case WHERE AccountId IN : personAccountIdToBusinessAccountId.keySet() ];
				for( Case recordCase : listOfCases ) {
					recordCase.AccountId = personAccountIdToBusinessAccountId.get( recordCase.AccountId );
				}
				UPDATE listOfCases;
			}
			catch( Exception e ) {
				response.setResponse( FALSE, 'Exception While Updating Cases:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
				
			}
		}
		return response;
	}
	
	/*
		@ PURPOSE : 1. RECEIVES A MAP OF PERSON ACCOUNT ID WITH ITS MATCHING BUSINESS ACCOUNT ID.
					2. RECEIVES ALSO A MAP OF PERSON ACCOUNT ID WITH PERSON ACCOUNT'S CONTACT ID.
					3. FETCHES OPPORTUNITIES FROM PERSON ACCOUNTS AND RE-PARENTS THEM TO BUSINESS ACCOUNTS.
					4. CREATES CONTACT ROLES IN THE COMBINATION OF OPPORTUNITIES AND PERSON ACCOUNTS' CONTACTS.
	*/
	private static PersonAccountsConversionResponse updateOpportunitiesToExistingBusinessAccounts( Map<ID,ID> personAccountIdToBusinessAccountId, 
																								   Map<ID,ID> personAccountIdToPersonAccountContactId 
	) {
		PersonAccountsConversionResponse response = new PersonAccountsConversionResponse();
		if( personAccountIdToBusinessAccountId != NULL && !personAccountIdToBusinessAccountId.isEmpty() ) {
			try {
				List<Opportunity> listOfOpportunities = [ SELECT ID, AccountId FROM Opportunity 
														  WHERE AccountId IN : personAccountIdToBusinessAccountId.keySet() 
													    ];
				List<OpportunityContactRole> listOfOpportunityContactRoles = new List<OpportunityContactRole>();
				for( Opportunity recordOpportunity : listOfOpportunities ) {
					
					listOfOpportunityContactRoles.add( new OpportunityContactRole
													   ( OpportunityId = recordOpportunity.Id,
													     ContactId = personAccountIdToPersonAccountContactId.get( recordOpportunity.AccountId ),
														 IsPrimary = TRUE
													   )
												     );
					recordOpportunity.AccountId = personAccountIdToBusinessAccountId.get( recordOpportunity.AccountId );
					
				}
				UPDATE listOfOpportunities;
				
				INSERT listOfOpportunityContactRoles;
			}
			catch( Exception e ) {
				response.setResponse( FALSE, 'Exception While Updating Opportunities:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
		}
		return response;
	}
	
	/*
		@ PURPOSE : UPDATES 'Convert_Person_Accounts__c' FIELD TO FALSE FOR PROCESSED BUSINESS ACCCOUNTS.
	*/
	private static void updateExistingBusinessAccounts( List<ID> listOfBusinessAccountIds ) {
		
		if( listOfBusinessAccountIds != NULL && !listOfBusinessAccountIds.isEmpty() ) {
			List<Account> listOfBusinessAccounts = new List<Account>();
			for( ID businessAccountId : listOfBusinessAccountIds ) {
				listOfBusinessAccounts.add( new Account( ID = businessAccountId, Convert_Person_Accounts__c = FALSE ) );
			}
			
			try {
				UPDATE listOfBusinessAccounts;
			}
			catch( Exception e ) {
				System.debug( 'Exception While Updating Master Business Accounts:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
		}
	}
	
	/*
		@ PURPOSE : 1. RECEIVES A MAP OF PERSON ACCOUNT ID WITH PERSON ACCOUNT'S CONTACT ID.
					2. FETCHES ATTACHMENTS AND CONTENT DOCUMENT LINKS OF PERSON ACCOUNTS.
					3. CLONES THESE RECORDS AND REPARENTS THEM TO CONTACTS AND INSERT THEM.
	*/
	private static PersonAccountsConversionResponse cloneAttachmentsAndContentDocumentsWithReparenting( Map<ID,ID> personAccountIdToPersonAccountContactId ) {
		
		PersonAccountsConversionResponse response = new PersonAccountsConversionResponse();
		if( personAccountIdToPersonAccountContactId != NULL && !personAccountIdToPersonAccountContactId.isEmpty() ) {
			
			try {
				List<Attachment> listOfClonedAttachments = new List<Attachment>();
				Attachment clonedAttachment;
				for( Attachment recordAttachment : [ SELECT ID, ParentId, Name, IsPrivate, ContentType, 
													 BodyLength, Body, OwnerId, Description 
													 FROM Attachment
													 WHERE ParentId IN : personAccountIdToPersonAccountContactId.keySet()
												   ] ) {
					clonedAttachment = recordAttachment.clone( FALSE, FALSE, FALSE, FALSE );
					clonedAttachment.Id = NULL;
					clonedAttachment.ParentId = personAccountIdToPersonAccountContactId.get( recordAttachment.ParentId );
                    listOfClonedAttachments.add( clonedAttachment );
				}
				if( !listOfClonedAttachments.isEmpty() ) {
					INSERT listOfClonedAttachments;
				}
				
				Set<ID> setOfPersonAccountIds = personAccountIdToPersonAccountContactId.keySet();
				List<ContentDocumentLink> listOfClonedContentDocumentLinks = new List<ContentDocumentLink>();
				ContentDocumentLink clonedContentDocumentLink;
				for( ContentDocumentLink recordContentDocumentLink : [ SELECT Id, LinkedEntityId, ContentDocumentId, ShareType, Visibility 
																	   FROM ContentDocumentLink
																	   WHERE LinkedEntityId IN : setOfPersonAccountIds
																	 ] ) {
					clonedContentDocumentLink = recordContentDocumentLink.clone( FALSE, FALSE, FALSE, FALSE );
					clonedContentDocumentLink.Id = NULL;
					clonedContentDocumentLink.LinkedEntityId = personAccountIdToPersonAccountContactId.get( recordContentDocumentLink.LinkedEntityId );
                    listOfClonedContentDocumentLinks.add( clonedContentDocumentLink );
				}
				if( !listOfClonedContentDocumentLinks.isEmpty() ) {
					INSERT listOfClonedContentDocumentLinks;
				}
			}
			catch( Exception e ) {
				response.setResponse( FALSE, 'Exception While Cloning Attachments:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
		}
		return response;
	}
}