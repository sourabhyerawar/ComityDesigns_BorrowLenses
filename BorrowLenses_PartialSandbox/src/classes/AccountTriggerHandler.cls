/*
	@ PURPOSE : HANDLES THE EVENTS FIRED BY AccountTrigger.trigger
*/
public class AccountTriggerHandler {
	
    public static void tryConvertPaToBaAndBc( List<Account> listOfAccounts ) {
        
		if( listOfAccounts != NULL && !listOfAccounts.isEmpty() ) {
			ID personAccountRecordTypeId = Account.SobjectType.getDescribe().getRecordTypeInfosByName().get( 'Person Account' ).getRecordTypeId();
			
			if( personAccountRecordTypeId != NULL ) {
				List<Account> listOfPersonAccounts = new List<Account>();
				Set<String> setOfDomainNames = new Set<String>();
				Set<ID> setOfPersonAccountIds = new Set<ID>();
				
				for( Account recordAccount : listOfAccounts ) {
					if( recordAccount.RecordTypeId == personAccountRecordTypeId ) {
						listOfPersonAccounts.add( recordAccount );
						setOfPersonAccountIds.add( recordAccount.Id );
					}
					if( String.isNotBlank( recordAccount.Email_Domain__pc ) ) {
						setOfDomainNames.add( recordAccount.Email_Domain__pc );
					}
				}
				
				if( !listOfPersonAccounts.isEmpty() && !setOfDomainNames.isEmpty() ) {
					List<Business_Account_Domain__c> listOfBusinessAccountDomains = getListOfBusinessAccountDomains( setOfDomainNames );
					if( !listOfBusinessAccountDomains.isEmpty() ) {
						
						Map<String,ID> domainNameToBusinessAccountId; 
						domainNameToBusinessAccountId = PersonAccountsConversionProcessHandler.getDomainNameToBusinessAccountId( listOfBusinessAccountDomains );
						if( !domainNameToBusinessAccountId.isEmpty() ) {
							listOfPersonAccounts = getListOfPersonAccountsWithEntitlements( domainNameToBusinessAccountId.keySet(), 
																							setOfPersonAccountIds 
																						  );
							PersonAccountsConversionProcessHandler.convertPaToBaAndBc( listOfBusinessAccountDomains, domainNameToBusinessAccountId, listOfPersonAccounts );
						}
					}
				}
			}
		}
    }
	
	/*
		@ PURPOSE : 1. RECEIVES THE SET OF DOMAIN NAMES.
					2. FETCHES THE LIST OF BUSINESS ACCOUNT DOMAINS.
	*/
	private static List<Business_Account_Domain__c> getListOfBusinessAccountDomains( Set<String> setOfDomainNames ) {
		
		List<Business_Account_Domain__c> listOfBusinessAccountDomains = new List<Business_Account_Domain__c>();
		if( setOfDomainNames != NULL && !setOfDomainNames.isEmpty() ) {
			try {
				listOfBusinessAccountDomains = [ SELECT ID, Account__c, Converted_Date_Time__c, Convert_Person_Accounts__c, Domain_Name__c
												 FROM Business_Account_Domain__c
												 WHERE 
												 Domain_Name__c IN : setOfDomainNames
											   ];
			}
			catch( Exception e ) {
				System.debug( 'Exception While Fetching Business Account Domains:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
		}
		return listOfBusinessAccountDomains;
	}
	
	/*
		@ PURPOSE : 1. RECEIVES THE SET OF DOMAIN NAMES FROM BUSINESS ACCOUNT DOMAINS AND SET OF PERSON ACCOUNT IDs.
					2. FETCHES PERSON ACCOUNTS WITH ENTITLEMENTS WHOSE EMAIL DOMAIN IS MATCHED.
	*/
	private static List<Account> getListOfPersonAccountsWithEntitlements( Set<String> setOfDomainNames, Set<ID> setOfPersonAccountIds ) {
		
		List<Account> listOfPersonAccounts = new List<Account>();
		if( setOfDomainNames != NULL && !setOfDomainNames.isEmpty() && setOfPersonAccountIds != NULL && !setOfPersonAccountIds.isEmpty() ) {
			try {
				listOfPersonAccounts = [ SELECT ID, PersonContactId, RecordTypeId, Email_Domain__pc,
									     ( SELECT ID, Name, AccountId, EndDate, Re_Parented__c FROM Entitlements ) 
										 FROM Account
										 WHERE 
										 ID IN : setOfPersonAccountIds
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
}