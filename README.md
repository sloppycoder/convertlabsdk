## ConvertLab SDK

Library to facilitate synchronizing your application object with ConvertLab cloud services. A very simple use case looks like the following:

```
ActiveRecord::Base.establish_connection

app_client = ConvertLab::AppClient.new
clab_id = app_client.customer.find(mobile: '13911223366')['records'].first['id']

# this is the customer record in local applicaiton that we want to synchronize to ConvertLab
ext_customer_info = { ext_channel: 'MY_SUPER_STORE', ext_type: 'customer',
                      ext_id: 'my_customer_id', clab_id: clab_id }
clab_customer = map_ext_customer_to_clab(ext_customer_info)
ConvertLab::SyncedCustomer.sync app_client.customer, clab_customer, ext_customer_info

```

For more details, generate API documentation and look around.

```
git clone <url_of_this_repo>
cd convertlabsdk
bundle install
rake yard
open doc/index.html
```


### Running the test 

```
# clone the repo first

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

# to start the web conosle 
rackup
open http://localhost:9292/syncer

```

See this [sync customer example](examples/sync_customer) for how to use the API in real world application.

### TODO
* review SycnedObject implementation for concurrency
* add filter entry/reset for console
* add tab to Resque web console to allow navigate back to Syncer
* (low) add async submit and forget support?
* (hold) implement sync_down and test cases (conflict with ext fields validation!)
* (hold) add caching to rest-client layer

