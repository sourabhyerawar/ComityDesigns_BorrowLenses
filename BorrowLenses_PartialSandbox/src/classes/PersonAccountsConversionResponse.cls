/*
	@ PURPOSE : HOLDS THE RESULT ( STATUS AND ERROR MESSAGE ) OF THE CONVERSION OF PERSON ACCOUNTS.
*/
public class PersonAccountsConversionResponse {
	
	public Boolean isSucceeded;
	
	public String strMessage;
	
	public PersonAccountsConversionResponse() {
		
		this.isSucceeded = TRUE;
		this.strMessage = '';
	}
	
	public void setResponse( Boolean isSucceeded, String strMessage ) {
			
		if( isSucceeded != NULL ) {
			this.isSucceeded = isSucceeded;
		}
		
		if( strMessage != NULL ) {
			this.strMessage = strMessage;
		}
	}
}