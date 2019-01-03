/*
    @ PURPOSE : 1. DETECTS THE LINKED ENTITY ID OF THE CONTENT DOCUMENT RECORD.
                2. CALCULATES 
					a. THE NUMBER OF STANDARD ATTACHMENTS AND CONTENT DOCUMENT LINKS AND 
					b. ALSO THE LATEST UPLOADED DATE/TIME ON PRIVATE ATTACHMENT OBJECT.
*/
Trigger ContentDocumentLinkTrigger on ContentDocumentLink ( After Insert ) {
    
    if( Trigger.isAfter ) {
        if( Trigger.isInsert ) {
            AttachmentTriggerHandler.calculatePrivateAttachments( Trigger.new );
        }
    }
}