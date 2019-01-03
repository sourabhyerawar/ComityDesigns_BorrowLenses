/*
	@ PURPOSE : TESTS THE FUNCTIONALITY OF CaseTrigger.
*/
@IsTest
public class CaseTriggerTest {
	
	private static final Integer intNoOfRecords = 10;
	
    @TestSetup static void insertTestData() {
        
        // INSERTS CASES.
        ID customerSupportCaseRecordTypeId = Case.SobjectType.getDescribe().getRecordTypeInfosByName().get( 'Customer Support' ).getRecordTypeId();
		List<Case> listOfCases = new List<Case>();
		
        List<String> listOfDepartments = new List<String>{ 'Verification', 'PO Accounts', 'Help' };
		Integer intDepartmentIndex = 0;
		
		for( Integer intCaseIndex = 0; intCaseIndex < intNoOfRecords; intCaseIndex ++ ) {
			
			if( intDepartmentIndex == 3 ) {
				intDepartmentIndex = 0;
			}
			
			Case recordCase = new Case 
						 ( 
						  Subject = 'Testing Of Making Attachments Private-' + intCaseIndex, 
						  RecordTypeId = customerSupportCaseRecordTypeId
						 );
			recordCase.Department__c = listOfDepartments.get( intDepartmentIndex++ );
			
            listOfCases.add( recordCase );
        }
        INSERT listOfCases;
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Case WHERE ID IN : listOfCases ] );
		
		// INSERTS STANDARD ATTACHMENTS.
        List<Attachment> listOfAttachments = new List<Attachment>();
        for( Case recordCase : listOfCases ) {
			listOfAttachments.add
							  ( new Attachment
								(
								  Name = recordCase.Id,
								  ParentId = recordCase.Id,
								  Body = Blob.valueOf( recordCase.Id ),
								  IsPrivate = FALSE
								)
							  );
        }
		INSERT listOfAttachments;
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Attachment WHERE ID IN : listOfAttachments ] );
		
        // INSERTS CONTENT VERSIONS.
        List<ContentVersion> listOfContentVersions = new List<ContentVersion>();
        for( Case recordCase : listOfCases ) {
            listOfContentVersions.add
                				  ( new ContentVersion
                                   	(
                                      Title = recordCase.Id,
                                      PathOnClient = recordCase.Id,
                                      VersionData = Blob.valueOf( recordCase.Id ),
                                      IsMajorVersion = TRUE
                                    )
                                  );
        }
        INSERT listOfContentVersions;
        listOfContentVersions = [ SELECT ID, ContentDocumentId FROM ContentVersion WHERE ID IN : listOfContentVersions ];
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM ContentVersion WHERE ID IN : listOfContentVersions ] );
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM ContentDocument ] );
		
		// INSERTS CONTENT DOCUMENT LINKS
		List<ContentDocumentLink> listOfContentDocumentLinks = new List<ContentDocumentLink>();
		for( Integer intCaseOrCvIndex = 0; intCaseOrCvIndex < intNoOfRecords; intCaseOrCvIndex ++ ) {
            listOfContentDocumentLinks.add
                                       ( new ContentDocumentLink
                                         (
                                          LinkedEntityId = listOfCases.get( intCaseOrCvIndex ).Id,
                                          ContentDocumentId = listOfContentVersions.get( intCaseOrCvIndex ).ContentDocumentId,
                                          ShareType = 'V'
                                         )
                                       );
        }
		
		INSERT listOfContentDocumentLinks;
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Case WHERE Number_Of_Private_Attachments__c = 0 ] );
    }
    
    public static TestMethod void testTryMakeAttachmentsPrivate() {
     	
		List<Case> listOfCasesToUpdate = [ SELECT ID, Department__c FROM Case WHERE Department__c = 'Help' ];
		List<String> listOfDepartments = new List<String>{ 'Verification', 'PO Accounts' };
		Integer intDepartmentIndex = 0;
		
		Test.startTest();
		
        for( Case recordCase : listOfCasesToUpdate ) {
			if( intDepartmentIndex == 2 ) {
				intDepartmentIndex = 0;
			}
			recordCase.Department__c = listOfDepartments.get( intDepartmentIndex++ );
		}
		UPDATE listOfCasesToUpdate;
        
        Test.stopTest();
        
        System.assertEquals( listOfCasesToUpdate.size(), [ SELECT COUNT() FROM Case WHERE Number_Of_Private_Attachments__c != 0 ] );
    }
	
	public static TestMethod void testUpdateDetailsWhenCaseClosed() {
     	
		List<Case> listOfCasesToUpdate = [ SELECT ID, Status FROM Case ];
		
		Test.startTest();
		
        for( Case recordCase : listOfCasesToUpdate ) {
			recordCase.Status = 'Closed';
		}
		UPDATE listOfCasesToUpdate;
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Case WHERE After_Case_Closed_Email_Received__c = FALSE ] );
		
		for( Case recordCase : listOfCasesToUpdate ) {
			recordCase.Status = 'New';
		}
		UPDATE listOfCasesToUpdate;
		
        Test.stopTest();
        
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Case WHERE Case_Closed_Type__c = 'Agent' ] );
    }
}