/*
	@ PURPOSE : HANDLES THE EVENTS TRIGGERED BY CaseTrigger.
*/
public without sharing class CaseTriggerHandler {
    
	// HOLDS THE LIST OF DEPARTMENT NAMES WHICH SHOULD HAVE PRIVATE ATTACHMENTS.
    private static final Set<String> SET_OF_PRIVATE_ATTACHMENT_DEPARTMENTS = new Set<String>{ 'verification', 'po accounts' };
	
	/*
		@ PURPOSE : FILTERS THE CASES BASED ON THE PRIVATE ATTACHMENT DEPARTMENT.
	*/
	public static void tryMakeAttachmentsPrivate( List<Case> listOfNewCases ) {
		
        if( listOfNewCases != NULL && !listOfNewCases.isEmpty() ) {
			List<Case> listOfCasesToMakePrivateAttachments = new List<Case>();
			
			for( Case newCase : listOfNewCases ) {
				if( String.isNotBlank( newCase.Department__c ) &&
					SET_OF_PRIVATE_ATTACHMENT_DEPARTMENTS.contains( newCase.Department__c.toLowerCase() ) 
				) {
					listOfCasesToMakePrivateAttachments.add( newCase );
				}
			}
			
			if( !listOfCasesToMakePrivateAttachments.isEmpty() ) {
				makeAttachmentsPrivate( JSON.serialize( listOfCasesToMakePrivateAttachments ) );
			}
		}
	}
	
    /*
    	@ PURPOSE : 1. IF CASE IS CLOSED, UPDATE After_Case_Closed_Email_Received__c FIELD TO FALSE.
					2. IF CASE IS RE-OPENED, UPDATE Case_Closed_Type__c TO 'AGENT'.
    */
    public static void updateDetailsWhenCaseClosed( List<Case> listOfNewCases, Map<ID,Case> caseIdToOldRecord ) {
        
        if( listOfNewCases != NULL && !listOfNewCases.isEmpty() && caseIdToOldRecord != NULL ) {
            Case oldCase;
			for( Case newCase : listOfNewCases ) {
                
                if( newCase.Status == 'Closed' ) {
                    oldCase = caseIdToOldRecord.get( newCase.Id );
                    if( oldCase == NULL || oldCase.Status != 'Closed') {
                        newCase.After_Case_Closed_Email_Received__c = FALSE;
                    }
                }
                else {
                    oldCase = caseIdToOldRecord.get( newCase.Id );
                    if( oldCase != NULL && oldCase.Status == 'Closed') {
                        newCase.Case_Closed_Type__c = 'Agent';
                    }
                }
            }
        }
    }
    
	/*
		@ PURPOSE : FILTERS THE CASES IF THE DEPARTMENT IS CHANGED TO PRIVATE ATTACHMENT DEPARTMENT.
	*/
	public static void tryMakeAttachmentsPrivate( List<Case> listOfNewCases, Map<ID,Case> caseIdToOldRecord ) {
		
        if( listOfNewCases != NULL && !listOfNewCases.isEmpty() && caseIdToOldRecord != NULL ) {
			List<Case> listOfCasesToMakePrivateAttachments = new List<Case>();
			Case oldCase;
			
			for( Case newCase : listOfNewCases ) {
				if( String.isNotBlank( newCase.Department__c ) &&
					SET_OF_PRIVATE_ATTACHMENT_DEPARTMENTS.contains( newCase.Department__c.toLowerCase() ) 
				) {
					oldCase = caseIdToOldRecord.get( newCase.Id );
					if( ( oldCase == NULL || String.isBlank( oldCase.Department__c ) ) || 
						( String.isNotBlank( oldCase.Department__c ) && 
                          !SET_OF_PRIVATE_ATTACHMENT_DEPARTMENTS.contains( oldCase.Department__c.toLowerCase() ) 
                        )
					) {
						listOfCasesToMakePrivateAttachments.add( newCase );
					}
				}
			}
			
			if( !listOfCasesToMakePrivateAttachments.isEmpty() ) {
				makeAttachmentsPrivate( JSON.serialize( listOfCasesToMakePrivateAttachments ) );
			}
		}
	}
	
	/*
		@ PURPOSE : 1. RECEIVES CASES WITH PRIVATE ATTACHMENT DEPARTMENT.
					2. FETCHES MAP OF CASE ID/EMAIL MESSAGE ID TO ITS OLDEST PRIVATE ATTACHMENT RECORD.
					3. FETCHES LIST OF STANDARD ATTACHMENTS AND CONTENT DOCUMENT LINKS FROM CASE OR EMAIL MESSAGE IDs.
					4. CLONES AND INSERTS THE STANDARD ATTACHMENTS WITH PARENT ID CHANGED FROM CASE ID/EMAIL MESSAGE ID TO PRIVATE ATTACHMENT ID.
					5. CLONES AND INSERTS THE CONETNT DOCUMENT LINKS WITH LINKED ENTITY ID CHANGED FROM CASE ID TO PRIVATE ATTACHMENT ID.
					6. DELETES THE OLD STANDARD ATTACHMENTS AND CONETNT DOCUMENT LINKS.
					7. ROLLS BACK EVERYTHING IF ANYTHING FAILS.
	*/
	@Future
	public static void makeAttachmentsPrivate( String strJsonListOfCasesToMakePrivateAttachments ) {
		
		if( String.isNotBlank( strJsonListOfCasesToMakePrivateAttachments ) ) {
			List<Case> listOfCasesToMakePrivateAttachments = new List<Case>();
			try {
				listOfCasesToMakePrivateAttachments = ( List<Case> ) JSON.deserialize( strJsonListOfCasesToMakePrivateAttachments, List<Case>.class );
			}
			catch( Exception e ) {
				System.debug( 'Exception:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
		
			if( !listOfCasesToMakePrivateAttachments.isEmpty() ) {
				Savepoint beforeMakePrivateSavePoint = Database.setSavePoint();
				
				Map<ID,Attachment__c> caseIdToPrivateAttachment = getCaseIdToPrivateAttachment( listOfCasesToMakePrivateAttachments );
				if( !caseIdToPrivateAttachment.isEmpty() ) {
					try {
						List<Attachment> listOfStandardAttachments = getListOfStandardAttachments( caseIdToPrivateAttachment.keySet() );
						if( !listOfStandardAttachments.isEmpty() ) {
							List<Attachment> listOfClonedStandardAttachments;
							listOfClonedStandardAttachments = getListOfClonedStandardAttachments( listOfStandardAttachments, caseIdToPrivateAttachment );
							if( !listOfStandardAttachments.isEmpty() ) {
								DELETE listOfStandardAttachments;
								INSERT listOfClonedStandardAttachments;
							}
						}
						
						List<ContentDocumentLink> listOfContentDocumentLinks = getListOfContentDocumentLinks( caseIdToPrivateAttachment.keySet() );
						if( !listOfContentDocumentLinks.isEmpty() ) {
							List<ContentDocumentLink> listOfClonedContentDocumentLinks;
							listOfClonedContentDocumentLinks = getListOfClonedContentDocumentLinks( listOfContentDocumentLinks, caseIdToPrivateAttachment );
							if( !listOfClonedContentDocumentLinks.isEmpty() ) {
								DELETE listOfContentDocumentLinks;
								INSERT listOfClonedContentDocumentLinks;
							}
						}
					}
					catch( Exception e ) {
						System.debug( 'Exception:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
						Database.rollBack( beforeMakePrivateSavePoint );
					}
				}
			}
		}
	}
	
	/*
		@ PURPOSE : 1. RECEIVES CASES WITH PRIVATE ATTACHMENT DEPARTMENT.
					2. FETCHES MAP OF CASE ID/EMAIL MESSAGE ID TO ITS OLDEST PRIVATE ATTACHMENT RECORD.
					3. CREATES THE PRIVATE ATTACHMENT RECORD FOR EACH CASE IF NOT AVAILABLE.
	*/
	private static Map<ID,Attachment__c> getCaseIdToPrivateAttachment( List<Case> listOfCases ) {
		
		Map<ID,Attachment__c> caseIdToPrivateAttachment = new Map<ID,Attachment__c>();
		if( listOfCases != NULL && !listOfCases.isEmpty() ) {
			
			try {
				List<Attachment__c> listOfNewPrivateAttachments = new List<Attachment__c>();
				Attachment__c newPrivateAttachment;
				
				for( Case recordCase : [ SELECT ID, ( SELECT ID FROM Private_Attachments__r ORDER BY CreatedDate ASC LIMIT 1 ),
										 ( SELECT ID, ParentId FROM EmailMessages )
										 FROM Case
										 WHERE ID IN : listOfCases
									   ] 
				) {
					if( !recordCase.Private_Attachments__r.isEmpty() ) {
						newPrivateAttachment = recordCase.Private_Attachments__r.get( 0 );
						caseIdToPrivateAttachment.put( recordCase.Id, newPrivateAttachment );
					}
					else {
						newPrivateAttachment = new Attachment__c( Case__c = recordCase.Id );
						caseIdToPrivateAttachment.put( recordCase.Id, newPrivateAttachment );
						listOfNewPrivateAttachments.add( newPrivateAttachment );
					}
					
					for( EmailMessage recordEmailMessage : recordCase.EmailMessages ) {
						caseIdToPrivateAttachment.put( recordEmailMessage.Id, newPrivateAttachment );
					}
				}
				if( !listOfNewPrivateAttachments.isEmpty() ) {
					INSERT listOfNewPrivateAttachments;
				}
			}
			catch( Exception e ) {
				System.debug( 'Exception:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
		}
		return caseIdToPrivateAttachment;
	}
	
	/*
		@ PURPOSE : FETCHES LIST OF ATTACHMENTS RELATED TO THE CASES WITH PRIVATE ATTACHMENT DEPARTMENT.
	*/
	private static List<Attachment> getListOfStandardAttachments( Set<ID> setOfCaseIds ) {
		
		List<Attachment> listOfStandardAttachments = new List<Attachment>();
		if( setOfCaseIds != NULL && !setOfCaseIds.isEmpty() ) {
			try {
				listOfStandardAttachments = [ SELECT ID, ParentId, Name, IsPrivate, ContentType, BodyLength, Body, OwnerId 
											  FROM Attachment
											  WHERE ParentId IN : setOfCaseIds
											];
			}
			catch( Exception e ) {
				System.debug( 'Exception:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
		}
		return listOfStandardAttachments;
	}
	
	/*
		@ PURPOSE : FETCHES THE CLONED LIST OF ATTACHMENTS WITH PARENT ID CHANGED FROM CASE ID/EMAIL MESSAGE ID TO PRIVATE ATTACHMENT ID.
	*/
	private static List<Attachment> getListOfClonedStandardAttachments( List<Attachment> listOfStandardAttachments, 
																		Map<ID,Attachment__c> caseIdToPrivateAttachment 
	) {
		List<Attachment> listOfClonedStandardAttachments = new List<Attachment>();
		if( listOfStandardAttachments != NULL && !listOfStandardAttachments.isEmpty() && caseIdToPrivateAttachment != NULL ) {
			Attachment clonedAttachment;
			Attachment__c privateAttachment;
			
			for( Attachment recordAttachment : listOfStandardAttachments ) {
				privateAttachment = caseIdToPrivateAttachment.get( recordAttachment.ParentId );
				
				if( privateAttachment != NULL ) {
					clonedAttachment = recordAttachment.clone( FALSE, FALSE, FALSE, FALSE );
					clonedAttachment.Id = NULL;
					clonedAttachment.ParentId = privateAttachment.Id;
					listOfClonedStandardAttachments.add( clonedAttachment );
				}
			}
		}
		return listOfClonedStandardAttachments;
	}
	
	/*
		@ PURPOSE : FETCHES LIST OF CONTENT DOCUMENT LINKS RELATED TO THE CASES WITH PRIVATE ATTACHMENT DEPARTMENT.
	*/
	private static List<ContentDocumentLink> getListOfContentDocumentLinks( Set<ID> setOfCaseIds ) {
		
		List<ContentDocumentLink> listOfContentDocumentLinks = new List<ContentDocumentLink>();
		if( setOfCaseIds != NULL && !setOfCaseIds.isEmpty() ) {
			try {
				listOfContentDocumentLinks = [ SELECT ID, LinkedEntityId, ContentDocumentId, ShareType, Visibility 
											   FROM ContentDocumentLink
											   WHERE LinkedEntityId IN : setOfCaseIds
											 ];
			}
			catch( Exception e ) {
				System.debug( 'Exception:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
		}
		return listOfContentDocumentLinks;
	}
	
	/*
		@ PURPOSE : FETCHES THE CLONED LIST OF CONTENTDOCUMENTLINKS WITH LINKED ENTITY ID CHANGED FROM CASE ID TO PRIVATE ATTACHMENT ID.
	*/
	private static List<ContentDocumentLink> getListOfClonedContentDocumentLinks( List<ContentDocumentLink> listOfContentDocumentLinks, 
																				  Map<ID,Attachment__c> caseIdToPrivateAttachment 
	) {
		List<ContentDocumentLink> listOfClonedContentDocumentLinks = new List<ContentDocumentLink>();
		if( listOfContentDocumentLinks != NULL && !listOfContentDocumentLinks.isEmpty() && caseIdToPrivateAttachment != NULL ) {
			ContentDocumentLink clonedContentDocumentLink;
			Attachment__c privateAttachment;
			
			for( ContentDocumentLink recordContentDocumentLink : listOfContentDocumentLinks ) {
				privateAttachment = caseIdToPrivateAttachment.get( recordContentDocumentLink.LinkedEntityId );
				
				if( privateAttachment != NULL ) {
					clonedContentDocumentLink = recordContentDocumentLink.clone( FALSE, FALSE, FALSE, FALSE );
					clonedContentDocumentLink.Id = NULL;
					clonedContentDocumentLink.LinkedEntityId = privateAttachment.Id;
					listOfClonedContentDocumentLinks.add( clonedContentDocumentLink );
				}
			}
		}
		return listOfClonedContentDocumentLinks;
	}
}