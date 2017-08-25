@isTest
private class AuthUtilsTest 
{
	// updated
	static testMethod void myUnitTest() 
    {
        Credentials__c cred = new Credentials__c(ConsumerSecret__c='123456987',Redirect_URL__c='001',ConsumerKey__c='1234569874563214569513578264');
        insert cred;
        AuthorizationDetails__c auth = new AuthorizationDetails__c(AuthorisedUser__c='test@testOrg.com', Name='test@testOrg.com', AccessToken__c='test', RefreshToken__c='test', InstanceURL__c='test');
        insert auth;
        Test.startTest();
        AuthUtils.sendRequest('https://Login.salesforce.com');
        AuthUtils.sendRequestWithToken('https://Login.salesforce.com','TestToken');
        AuthUtils.checkAuthentication(auth);
        AuthUtils.reAuthenticateWithRefreshToken('TestToken');
        AuthUtils.reAuthenticateWithRefreshToken('TestToken','Sandbox');
       // AuthUtils.getValue('response', 'key');
        AuthUtils.getCompleteDetails('https://Login.salesforce.com', 'Production', 'login', 'TestToken');
        Test.stopTest();
        System.assertNotEquals(cred.Id, null);
    }
    
	static testMethod void myUnitTest1() 
	{
        AuthUtils.getCompleteDetails('https://Login.salesforce.com', 'Production', 'login', 'TestToken');
		Credentials__c cred = new Credentials__c(ConsumerSecret__c='123456987',Redirect_URL__c='001',ConsumerKey__c='1234569874563214569513578264');
        insert cred;
        Test.startTest();
        AuthUtils.sendRequest(null);
        AuthUtils.sendRequestWithToken(null,null);
       // AuthUtils.checkAuthentication('Test');
        AuthUtils.reAuthenticateWithRefreshToken('TestToken');
        AuthUtils.reAuthenticateWithRefreshToken('TestToken','Sandbox');
        AuthUtils.getValue(null, 'key');
        AuthUtils.getCompleteDetails(null, null, null, null);
        Test.stopTest();
        System.assertNotEquals(cred.Id, null);
    }
}
