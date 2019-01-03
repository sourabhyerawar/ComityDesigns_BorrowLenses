/*
    @ PURPOSE : 1. FETCHES ALL PRIVATE ATTACHMENT RECORDS WHEN CONTENT DOCUMEN TTRIGGER RECORDS GET DELETED.
                2. CALCULATES 
					a. THE NUMBER OF STANDARD ATTACHMENTS AND CONTENT DOCUMENT LINKS AND 
					b. ALSO THE LATEST UPLOADED DATE/TIME ON PRIVATE ATTACHMENT OBJECT.
*/
Trigger ContentDocumentTrigger on ContentDocument ( After Delete ) {
	
    if( Trigger.isAfter ) {
        if( Trigger.isDelete ) {
            
            try {
                Set<ID> setOfPrivateAttachments = new Map<ID,Attachment__c>([SELECT ID FROM Attachment__c]).keySet();
                if( !setOfPrivateAttachments.isEmpty() ) {
                    AttachmentTriggerHandler.updatePrivateAttachments( setOfPrivateAttachments );
                }
            }
            catch( Exception e ) {
				System.debug( 'Exception:-\n' + e.getMessage() + '\nLine Number:-\n' + e.getLineNumber() );
			}
    	}
    }
}