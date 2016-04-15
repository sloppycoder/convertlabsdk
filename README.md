## convertlabsdk

Library to facilitate synchronizing your application object with ConvertLab cloud services

## modules

### AppClient
client application that access the cloud APIs.
* handling authentication and access_token
* provide wrapper to access objects provided by APIs. 
	channelaccount
	customer
	event
	deal

### SyncedObject
helpers that facilitate syncing of external objects to convertlab cloud services locally maintain external object and cloud object mappings it mains a local datastore that stores the mapping:
* clab object type and id
* external object type and id
* last update of local object attributes
* last upload to clab
* last download from clab (to be sync back to external app)??

### Running the test and check the coverage report

```
git clone <url_of_this_repo>
cd convertlabsdk
bundle install
COVERAGE=1 appid=<appid> scecret=<secret> rake test 
cd coverage
open index.html
```

By default the test will not send request to API server but uses VCR cassette files instead. This ensures the repeatbility of the test result. To always send request to server,

```
NO_VCR=1 rake test
```

To run individual test case files, ``` ruby -I 'test' test/<your_test>.rb ```

### TODO
* add object access APIs in AppClient class similiar to channelaccount
* implement local storage helper to keep tracking of mapping (big)
* add SSL::VERIFY option to Resources
* store access token in file so that they can be shared amount multiple processes (CLAB only allows 1 active access token per appid)
* implement logging

### Issue with APIs
1. search for customer only filter on mobile, other filters are ignored. this is not consistent with API reference. channelaccounts can be searched by any filter
2. create new customer with same mobile number will return an existing record instead of creating a new one. channelaccounts can create different record with exact same attributes
3. delete custoemr always return 204, even when id is invalid. delete channelaccount always return http status 500. though the record seems to be deleted correctly.
4. get customer and channel with invalid id  will return 500. should be 404?
5. post to customer with invalid access token returns http status 200, with error message in body. should be 401?
6. standard oauth2 style http header 'Authorization: Bearer ' does not work. require access_token as url parameter is clunky and cause problem with VCR recording




