/*
    @ PURPOSE : 1. IF CASE DEPARTMENT__C IS CHANGED TO 'Verification' or 'PO_Accounts' THEN,
                    a. CREATES ONE ATTACHMENT__C RECORD FOR THIS CASE IF NOT AVAILABLE.
                    b. RE-PARENT ALL STANDARD ATTACHMENTS AND CONTENT DOCUMENT LINKS.
                2. IF CASE IS CLOSED OR RE-OPENED, UPDATE CASE DETAILS.  
*/
Trigger CaseTrigger on Case ( Before Insert, Before Update ) {
    
    if( Trigger.IsBefore ) {
        
        if( Trigger.isInsert ) {
            CaseTriggerHandler.tryMakeAttachmentsPrivate( Trigger.New );
        }
        else if( Trigger.isUpdate ) {
            CaseTriggerHandler.updateDetailsWhenCaseClosed( Trigger.New, Trigger.oldMap );
            CaseTriggerHandler.tryMakeAttachmentsPrivate( Trigger.New, Trigger.oldMap );
        }
    }
}