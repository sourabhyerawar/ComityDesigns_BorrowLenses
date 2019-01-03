/*
	@ PURPOSE : TESTS THE FUNCTIONALITY OF ContentDocumentLinkTrigger.
*/
@IsTest
public class ContentDocumentLinkTriggerTest {
	
	private static final Integer intNoOfRecords = 10;
	
    @TestSetup static void insertTestData() {
        
        // INSERTS CASES.
        ID customerSupportCaseRecordTypeId = Case.SobjectType.getDescribe().getRecordTypeInfosByName().get( 'Customer Support' ).getRecordTypeId();
		List<Case> listOfCases = new List<Case>();
		for( Integer intCaseIndex = 0; intCaseIndex < intNoOfRecords; intCaseIndex ++ ) {
            listOfCases.add( 
							new Case 
							( 
							 Subject = 'Testing Attachment-' + intCaseIndex, 
							 RecordTypeId = customerSupportCaseRecordTypeId, 
							 Department__c = 'Verification' 
						    ) 
                           );
        }
        INSERT listOfCases;
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Case WHERE ID IN : listOfCases ] );
		listOfCases = [ SELECT ID, CaseNumber, Subject FROM Case ];
        
		// INSERTS PRIVATE ATTACHMENTS
		List<Attachment__c> listOfAttachments = new List<Attachment__c>();
		for( Case recordCase : listOfCases ) {
            listOfAttachments.add( 
								  new Attachment__c
								  ( 
								   Case__c = recordCase.Id 
								  ) 
								 );
        }
        INSERT listOfAttachments;
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Attachment__c WHERE ID IN : listOfAttachments ] );
		
        // INSERTS CONTENT VERSIONS.
        List<ContentVersion> listOfContentVersions = new List<ContentVersion>();
        listOfCases = [ SELECT ID, CaseNumber FROM Case ];
        for( Attachment__c privateAttachment : listOfAttachments ) {
            listOfContentVersions.add
                				  ( new ContentVersion
                                   	(
                                      Title = privateAttachment.Id,
                                      PathOnClient = privateAttachment.Id,
                                      VersionData = Blob.valueOf( privateAttachment.Id ),
                                      IsMajorVersion = TRUE
                                    )
                                  );
        }
        INSERT listOfContentVersions;
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM ContentVersion WHERE ID IN : listOfContentVersions ] );
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM ContentDocument ] );
    }
    
    public static TestMethod void testCalculatePrivateAttachments() {
     	
		Test.startTest();
		
		List<ContentDocumentLink> listOfContentDocumentLinks = new List<ContentDocumentLink>();    
        List<ContentVersion> listOfContentVersions = [ SELECT ID, ContentDocumentId FROM ContentVersion ];
		
        Set<ID> setOfPrivateAttachmentIds = new Map<ID,Attachment__c>([ SELECT ID FROM Attachment__c ]).keySet();
		System.assertEquals( intNoOfRecords, setOfPrivateAttachmentIds.size() );
		List<ID> listOfPrivateAttachmentIds = new List<ID>( setOfPrivateAttachmentIds );
        
		for( Integer intPaOrCvIndex = 0; intPaOrCvIndex < intNoOfRecords; intPaOrCvIndex ++ ) {
            listOfContentDocumentLinks.add
                                       ( new ContentDocumentLink
                                         (
                                          LinkedEntityId = listOfPrivateAttachmentIds.get( intPaOrCvIndex ),
                                          ContentDocumentId = listOfContentVersions.get( intPaOrCvIndex ).ContentDocumentId,
                                          ShareType = 'V'
                                         )
                                       );
        }
		
		INSERT listOfContentDocumentLinks;
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId IN : setOfPrivateAttachmentIds ] );
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Case WHERE Number_Of_Private_Attachments__c != 0 ] );
        
        // DELETES CONTENT DOCUMENTS
        DELETE [ SELECT ID FROM ContentDocument ];
        
        Test.stopTest();
        
        System.assertEquals( 0, [ SELECT COUNT() FROM Case WHERE Number_Of_Private_Attachments__c != 0 ] );
    }
}