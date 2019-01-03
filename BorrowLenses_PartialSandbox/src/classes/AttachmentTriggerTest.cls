/*
	@ PURPOSE : TESTS THE FUNCTIONALITY OF AttachmentTrigger.
*/
@IsTest
public class AttachmentTriggerTest {
	
    private static final Integer intNoOfRecords = 10;
	
    @TestSetup static void insertTestData() {
		
        // INSERTS CASES.
		ID verificationQueueId = [ SELECT QueueId FROM QueueSobject 
								   WHERE Queue.Name = 'Verification' AND SobjectType = 'Case' 
								   LIMIT 1 
							     ][0].QueueId;
		
        ID customerSupportCaseRecordTypeId = Case.SobjectType.getDescribe().getRecordTypeInfosByName().get( 'Customer Support' ).getRecordTypeId();
		List<Case> listOfCases = new List<Case>();
		for( Integer intCaseIndex = 0; intCaseIndex < intNoOfRecords; intCaseIndex ++ ) {
            listOfCases.add( new Case ( Subject = 'Testing Attachment-' + intCaseIndex, 
                                       	RecordTypeId = customerSupportCaseRecordTypeId, 
                                        OwnerId = verificationQueueId 
                                      )
                           );
        }
        INSERT listOfCases;
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Case WHERE ID IN : listOfCases ] );
		listOfCases = [ SELECT ID, CaseNumber, Subject FROM Case ];
		
		// INSERT INBOUND EMAIL MESSAGES
		List<EmailMessage> listOfEmailMessages = new List<EmailMessage>();
		for( Case recordCase : listOfCases ) {
            listOfEmailMessages.add( new EmailMessage 
									 ( Subject = recordCase.Subject, 
                                       Incoming = TRUE,
									   ParentId = recordCase.Id
                                     ) 
								   );
        }
        INSERT listOfEmailMessages;
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM EmailMessage WHERE ID IN : listOfEmailMessages ] );
    }
    
    public static TestMethod void testReParentFromEmailMessageToPrivateAttachment() {
		
		List<EmailMessage> listOfEmailMessages = [ SELECT ID, Subject FROM EmailMessage ];
		
        Test.startTest();
		
		// INSERTS STANDARD ATTACHMENTS.
        List<Attachment> listOfAttachments = new List<Attachment>();
        for( EmailMessage recordEmailMessage : listOfEmailMessages ) {
			listOfAttachments.add
							  ( new Attachment
								(
								  Name = recordEmailMessage.Subject,
								  ParentId = recordEmailMessage.Id,
								  Body = Blob.valueOf( recordEmailMessage.Subject ),
								  IsPrivate = FALSE
								)
							  );
        }
		INSERT listOfAttachments;
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Attachment WHERE ID IN : listOfAttachments ] );
        
		Test.stopTest();
        
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Attachment__c ] );
		System.assertEquals( 0, [ SELECT COUNT() FROM Attachment WHERE ParentId IN : listOfEmailMessages ] );
		System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Attachment WHERE ParentId IN ( SELECT ID FROM Attachment__c ) ] );
		System.assertNotEquals( 0, [ SELECT COUNT() FROM Case WHERE Number_Of_Private_Attachments__c != 0 ] );
    }
	
	public static TestMethod void testCalculatePrivateAttachments() {
		
		List<EmailMessage> listOfEmailMessages = [ SELECT ID, Subject FROM EmailMessage ];
		
        Test.startTest();
		
		// INSERTS STANDARD ATTACHMENTS.
        List<Attachment> listOfAttachments = new List<Attachment>();
        for( EmailMessage recordEmailMessage : listOfEmailMessages ) {
			listOfAttachments.add
							  ( new Attachment
								(
								  Name = recordEmailMessage.Subject,
								  ParentId = recordEmailMessage.Id,
								  Body = Blob.valueOf( recordEmailMessage.Subject ),
								  IsPrivate = FALSE
								)
							  );
        }
		INSERT listOfAttachments;
        System.assertEquals( intNoOfRecords, [ SELECT COUNT() FROM Attachment WHERE ID IN : listOfAttachments ] );
		
        // DELETES STANDARD ATTACHMENTS.
		DELETE listOfAttachments;
		
		Test.stopTest();
		
		System.assertEquals( 0, [ SELECT COUNT() FROM Case WHERE Number_Of_Private_Attachments__c != 0 ] );
    }
}