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

...

### Running the test 

```
git clone <url_of_this_repo>
cd convertlabsdk
bundle install

# set CLAB APPID and SECRET in envronment variables
export CLAB_APPID=<appid>
export CLAB_SECRET=<secret>

# run test with VCR cassettes
rake test

# bypass VCR and send request to servers and log request/response to the console
NO_VCR=1 RESTCLIENT_LOG=stdout rake test 

# run the tests and display slowest 10 test cases
NO_VCR=1 ruby test/test_convertlabsdk.rb --profile

# to get coverage report
COVERAGE=1 rake test
cd coverage
open index.html

# the test cases nromally does cleanup after themselves. In some cases, the test case execution is 
# interrupted# eitehr due to test failure or user intervention, the test data remaining in the 
# system can cause next test execution to fail. When this happens, run this script to cleanup 
# the data, then run the test cases again

ruby test/cleanup_testdata.rb

# to run individual test case files
ruby test/test_<whatever>.rb

```

### TODO
* create complete examples
	* multi worker example based on Resque
* document classes and pbulic APIs using rdoc. maybe YARD?
* review SycnedObject implementation for concurrency
* (low) add async submit and forget support?
* (hold) implement sync_down and test cases (conflict with ext fields validation!)
* (hold) add caching to rest-client layer

