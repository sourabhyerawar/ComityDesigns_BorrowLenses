/*
	@ PURPOSE : 1. RECEIVES BUSINESS ACCOUNT DOMAIN IDs WHOSE 'CONVERT PERSON ACCOUNTS' CHECKBOX FIELD IS MARKED.
				2. FETCHES PERSON ACCOUNTS WHOSE DOMAIN IN EMAIL ADDRESS IS SAME AS THAT OF DOMAIN NAME OF BUSINESS DOMAIN RECORDS.
				3. UPDATES THE RECORD TYPE OF PERSON ACCOUNTS TO BUSINESS ACCOUNT.
				4. PERSON CONTACTS WILL BE UPDATED TO BUSINESS CONTACTS AUTOMATICALLY.
				5. UPDATES ACCOUNT FIELD OF BUSINESS CONTACTS WITH EXISTING BUSINESS ACCOUNT.
				6. REPARENTS THE CASES AND OPPORTUNITIES FROM PERSON ACCOUNTS TO EXISTING BUSINESS ACCOUNT.
				7. CREATES OPPORTUNITY CONTACT ROLES WITH THE COMBINATION OF OPPORTUNITIES AND BUSINESS CONTACTS.
				8. CLONES ATTACHMENTS AND CONTENT DOCUMENT LINKS FROM PERSON ACCOUNTS TO BUSINESS CONTACTS.
				9. REPARENTS THE ENTITLEMENTS FROM PERSON ACCOUNTS TO BUSINESS ACCOUNTS AND UPDATES OTHER FIELDS.
				10. DELETES THE PERSON ACCOUNTS ( WHOSE RECORD TYPE IS JUST UPDATED TO BUSINESS ACCOUNT ).
				11. UPDATES BUSINESS ACCOUNT DOMAINS WITH 'CONVERT PERSON ACCOUNTS' AS FALSE.
*/
public class BusinessAccountDomainProcessHandler {
	
	/*
		@ PURPOSE : 1. RECEIVES BUSINESS ACCOUNT DOMAIN IDs WHOSE 'CONVERT PERSON ACCOUNTS' CHECKBOX FIELD IS MARKED.
					2. FETCHES BUSINESS ACCOUNT DOMAIN RECORDS FROM THEIR IDs.
					3. CONVERTS THE MATCHING PERSON ACCOUNTS.
					4. UPDATES BUSINESS ACCOUNT DOMAINS WITH 'CONVERT PERSON ACCOUNTS' AS FALSE.
	*/
    @InvocableMethod
	public static void convertPaToBaAndBc( List<ID> listOfBusinessAccountDomainIds ) {
        
        if( listOfBusinessAccountDomainIds != NULL && !listOfBusinessAccountDomainIds.isEmpty() ) {
            try {
				List<Business_Account_Domain__c> listOfBusinessAccountDomains = [ SELECT ID, Account__c, Converted_Date_Time__c, 
																				  Convert_Person_Accounts__c, Domain_Name__c
																				  FROM Business_Account_Domain__c
																				  WHERE 
																				  ID IN : listOfBusinessAccountDomainIds
																					AND
																				  Domain_Name__c != NULL
																			    ];
				if( !listOfBusinessAccountDomains.isEmpty() ) {
					PersonAccountsConversionProcessHandler.convertPaToBaAndBc( listOfBusinessAccountDomains );
				}
			}
			catch( Exception e ) {
				System.debug( 'Exception While Fetching Business Account Domains:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
			finally {
				updateBusinessAccountDomains( listOfBusinessAccountDomainIds );
			}
        }
    }
	
	/*
		@ PURPOSE : UPDATES 'Convert_Person_Accounts__c' FIELD TO FALSE FOR PROCESSED BUSINESS ACCCOUNT DOMAINS.
	*/
	private static void updateBusinessAccountDomains( List<ID> listOfBusinessAccountDomainIds ) {
		
		if( listOfBusinessAccountDomainIds != NULL && !listOfBusinessAccountDomainIds.isEmpty() ) {
			List<Business_Account_Domain__c> listOfBusinessAccountDomains = new List<Business_Account_Domain__c>();
			for( ID businessAccountDomainId : listOfBusinessAccountDomainIds ) {
				listOfBusinessAccountDomains.add( new Business_Account_Domain__c( ID = businessAccountDomainId, Convert_Person_Accounts__c = FALSE ) );
			}
			
			try {
				UPDATE listOfBusinessAccountDomains;
			}
			catch( Exception e ) {
				System.debug( 'Exception While Updating Business Account Domains:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
		}
	}
}