/*
	@ PURPOSE : HANDLES THE EVENTS TRIGGERED BY AttachmentTrigger, ContentDocumentTrigger, AND ContentDocumentLinkTrigger.
*/
public class AttachmentTriggerHandler {
	
    /*
		@ PURPOSE : 1. CHECKS IF PARENT ID OF ATTACHMENT RECORD IS EMAIL MESSAGE.
					2. FINDS THE CASE RECORD FROM EMAIL MESSAGE AND OLDEST PRIVATE ATTACHMENT RECORD FROM THAT CASE RECORD.
					3. REPARENTS THE PARENT OF ATTACHMENT RECORD FROM EMAIL MESSAGE TO THIS OLDEST PRIVATE ATTACHMENT RECORD.
	*/
	public static void reParentFromEmailMessageToPrivateAttachment( List<Attachment> listOfAttachments ) {
        
		if( listOfAttachments != NULL && !listOfAttachments.isEmpty() ) {
            Set<ID> setOfEmailMessageIds = new Set<ID>();
            String strParentId;
            
			for( Attachment recordAttachment : listOfAttachments ) {
                strParentId = recordAttachment.ParentId;
                
                // INBOUND EMAIL MESSAGE WILL BE PARENT OF ATTACHMENT RECORD IN EMAIL-TO-CASE SCENARION
				// CASE RECORD WILL BE PARENT OF EMAIL MESSAGE.
				if( String.isNotBlank( strParentId ) && strParentId.startsWith( '02s' ) ) {
					setOfEmailMessageIds.add( strParentId );
				}
            }
            
            if( !setOfEmailMessageIds.isEmpty() ) {
                Map<ID,ID> emailMessageIdToCaseId = getEmailMessageIdToCaseId( setOfEmailMessageIds );
				
				if( !emailMessageIdToCaseId.isEmpty() ) {
					Map<ID,ID> caseIdToAttachmentId = getCaseIdToAttachmentId( emailMessageIdToCaseId.values() );
					if( !caseIdToAttachmentId.isEmpty() ) {
						
						for( Attachment recordAttachment : listOfAttachments ) {
							
							// UPDATES PARENT ID FROM EMAIL MESSAGE TO CASE RECORD IF EMAIL MESSAGE IS PARENT OF AN ATTACHMENT.
							if( emailMessageIdToCaseId.containsKey( recordAttachment.ParentId ) ) {
								strParentId = emailMessageIdToCaseId.get( recordAttachment.ParentId );
								if( String.isNotBlank( strParentId ) ) {
									recordAttachment.ParentId = strParentId;
								}
							}
							
							// UPDATES PARENT ID FROM CASE TO ATTACHMENT__C RECORD.
							strParentId = caseIdToAttachmentId.get( recordAttachment.ParentId );
							if( String.isNotBlank( strParentId ) ) {
								recordAttachment.ParentId = strParentId;
							}
						}
					}
				}
            }
        }
    }
	
	/*
		@ PURPOSE : 1. FILTERS ATTACHMENT RECORDS WHOSE PARENT IS PRIVATE ATTACHMENT RECORD.
					2. CALCULATES THE ATTACHMENTS AND CONTENTDOCUMENTLINKS FOR PRIVATE ATTACHMENTS AND UPDATES THEM.
	*/
	public static void calculatePrivateAttachments( List<Attachment> listOfAttachments ) {
		
		if( listOfAttachments != NULL && !listOfAttachments.isEmpty() ) {
			String strParentId, strPrivateAttachmentKeyPrefix = Attachment__c.sObjectType.getDescribe().getKeyPrefix();
			Set<ID> setOfPrivateAttachmentIds = new Set<ID>();
			
			for( Attachment recordAttachment : listOfAttachments ) {
				strParentId = recordAttachment.ParentId;
				if( String.isNotBlank( strParentId ) && strParentId.startsWith( strPrivateAttachmentKeyPrefix ) ) {
					setOfPrivateAttachmentIds.add( strParentId );
				}
			}
			
			if( !setOfPrivateAttachmentIds.isEmpty() ) {
				updatePrivateAttachments( setOfPrivateAttachmentIds );
			}
		}
	}
	
	/*
		@ PURPOSE : 1. FILTERS CONTENTDOCUMENTLINK RECORDS WHOSE PARENT IS PRIVATE ATTACHMENT RECORD.
					2. CALCULATES THE ATTACHMENTS AND CONTENTDOCUMENTLINKS FOR PRIVATE ATTACHMENTS AND UPDATES THEM.
	*/
	public static void calculatePrivateAttachments( List<ContentDocumentLink> listOfContentDocumentLinks ) {
		
		if( listOfContentDocumentLinks != NULL && !listOfContentDocumentLinks.isEmpty() ) {
			String strLinkedEntityId, strPrivateAttachmentKeyPrefix = Attachment__c.sObjectType.getDescribe().getKeyPrefix();
			Set<ID> setOfPrivateAttachmentIds = new Set<ID>();
			
			for( ContentDocumentLink cdl : listOfContentDocumentLinks ) {
                strLinkedEntityId = cdl.LinkedEntityId;
                if( String.isNotBlank( strLinkedEntityId ) && strLinkedEntityId.startsWith( strPrivateAttachmentKeyPrefix ) ) {
                    setOfPrivateAttachmentIds.add( strLinkedEntityId );
                }
            }
			
			if( !setOfPrivateAttachmentIds.isEmpty() ) {
				updatePrivateAttachments( setOfPrivateAttachmentIds );
			}
		}
	}
	
	/*
		@ PURPOSE : 1. FETCHES ATTACHMENT AND CONTENTDOCUMENTLINK RECORDS FROM PRIVATE ATTACHMENT RECORDS.
					2. CALCULATES THE NUMBER OF ATTACHMENTS AND CONTENTDOCUMENTLINKS AND LATEST UPLOADED CHILD RECORD.
					3. UPDATES THE PRIVATE ATTACHMENT RECORDS ACCORDINGLY.
	*/
	public static void updatePrivateAttachments( Set<ID> setOfPrivateAttachmentIds ) {
		
		if( setOfPrivateAttachmentIds != NULL && !setOfPrivateAttachmentIds.isEmpty() ) {
			try {
				List<Attachment__c> listOfPrivateAttachments = [ SELECT ID, Number_of_Attachments__c, Latest_Attachment_Uploaded_Date_Time__c,
																( SELECT ID, SystemModstamp FROM ContentDocumentLinks ORDER BY SystemModstamp DESC ),
																( SELECT ID, SystemModstamp FROM Attachments ORDER BY SystemModstamp DESC )
																FROM Attachment__c
																WHERE ID IN : setOfPrivateAttachmentIds
															   ];
				for( Attachment__c privateAttachment : listOfPrivateAttachments ) {
					privateAttachment.Number_of_Attachments__c = privateAttachment.Attachments.size() + privateAttachment.ContentDocumentLinks.size();
					
					if( !privateAttachment.Attachments.isEmpty() && !privateAttachment.ContentDocumentLinks.isEmpty() ) {
						if( privateAttachment.Attachments.get( 0 ).SystemModstamp > privateAttachment.ContentDocumentLinks.get( 0 ).SystemModstamp ) {
							privateAttachment.Latest_Attachment_Uploaded_Date_Time__c = privateAttachment.Attachments.get( 0 ).SystemModstamp;
						}
						else {
							privateAttachment.Latest_Attachment_Uploaded_Date_Time__c = privateAttachment.ContentDocumentLinks.get( 0 ).SystemModstamp;
						}
					}
					else if( !privateAttachment.Attachments.isEmpty() ) {
						privateAttachment.Latest_Attachment_Uploaded_Date_Time__c = privateAttachment.Attachments.get( 0 ).SystemModstamp;
					}
					else if( !privateAttachment.ContentDocumentLinks.isEmpty() ) {
						privateAttachment.Latest_Attachment_Uploaded_Date_Time__c = privateAttachment.ContentDocumentLinks.get( 0 ).SystemModstamp;
					}
				}
				UPDATE listOfPrivateAttachments;
			}
			catch( Exception e ) {
				System.debug( 'Exception:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
		}
	}
	
	/*
		@ PURPOSE : CREATES A MAP OF EMAIL MESSAGE RECORD ID WITH ITS CASE ID FROM LIST OF EMAIL MESSAGE RECORDS.
	*/
    private static Map<ID,ID> getEmailMessageIdToCaseId( Set<ID> setOfEmailMessageIds ) {
        
        Map<ID,ID> emailMessageIdToCaseId = new Map<ID,ID>();
        if( setOfEmailMessageIds != NULL && !setOfEmailMessageIds.isEmpty() ) {
            try {
				for( EmailMessage recordEmailMessage : [ SELECT ID, ParentId FROM EmailMessage 
														 WHERE ID IN : setOfEmailMessageIds
															AND
														 ParentId != NULL
													   ] ) {
					emailMessageIdToCaseId.put( recordEmailMessage.Id, recordEmailMessage.ParentId );
				}
			}
			catch( Exception e ) {
				System.debug( 'Exception:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
        }
        return emailMessageIdToCaseId;
    }
    
	/*
		@ PURPOSE : CREATES A MAP OF CASE ID WITH ITS OLDEST PRIVATE ATTACHMENT RECORD ID FROM LIST OF CASE IDs.
	*/
    private static Map<ID,ID> getCaseIdToAttachmentId( List<ID> listOfCaseIds ) {
        
        Map<ID,ID> caseIdToAttachmentId = new Map<ID,ID>();
        if( listOfCaseIds != NULL && !listOfCaseIds.isEmpty() ) {
            try {
				for( Attachment__c recordAttachment : [ SELECT ID, Case__c FROM Attachment__c 
														WHERE Case__c IN : listOfCaseIds 
														ORDER BY CreatedDate DESC 
													  ] ) {
					caseIdToAttachmentId.put( recordAttachment.Case__c, recordAttachment.Id );
				}
			}
			catch( Exception e ) {
				System.debug( 'Exception:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
        }
        return caseIdToAttachmentId;
    }
}