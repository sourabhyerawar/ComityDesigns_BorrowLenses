/*
    @ PURPOSE : 1. DETECTS THE PARENT ID OF ATTACHMENT RECORD.
                2. IF THE PARENT RECORD IS A EMAIL MESSAGE RECORD THEN CHANGES
					a. THE PARENT ID FROM EMAIL MESSAGE RECORD TO OLDEST ATTACHMENT__C RECORD OF ITS CASE RECORD.
				3. CALCULATES ( WHEN INSERTED OR DELETED )
					a. THE NUMBER OF STANDARD ATTACHMENTS
					b. ALSO THE LATEST UPLOADED DATE/TIME ON PRIVATE ATTACHMENT OBJECT RECORDS.
*/
Trigger AttachmentTrigger on Attachment ( Before Insert, After Insert, After Delete ) {
    
    if( Trigger.isBefore ) {
		if( Trigger.isInsert ) {
            AttachmentTriggerHandler.reParentFromEmailMessageToPrivateAttachment( Trigger.new );
        }
    }
    else {
        if( Trigger.isInsert ) {
            AttachmentTriggerHandler.calculatePrivateAttachments( Trigger.new );
        }
        else if( Trigger.isDelete ) {
            AttachmentTriggerHandler.calculatePrivateAttachments( Trigger.old );
        }
    }
}