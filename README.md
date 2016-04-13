##convertlabsdk

Library to facilitate synchronizing your application object with ConvertLab cloud services

## modules

### AppClient
client application that access the cloud APIs.
* handling authentication and access_token
* provide wrapper to access objects provided by APIs. 
	customer (include channelaccount)
	event
	deal

### SyncedObject
helpers that facilitate syncing of external objects to convertlab cloud services locally maintain external object and cloud object mappings it mains a local datastore that stores the mapping:
* clab object type and id
* external object type and id
* last update of local object attributes
* last upload to clab
* last download from clab (to be sync back to external app)??

### Running the test
1. git clone <url_of_this_repo>
2. cd convertlabsdk
3. bundle install
4. rake test


### TODO
* add object access APIs in AppClient class (new classes outside AppClient?)
* add vcr to test cases to allow offline testing
* (low) study RSpec vs MiniTest vs Test::Unit
* implent local storage helper to keep tracking of mapping (big)

