## Sync customer demo program

This is a simple program that upload customer infomration into ConvertLab cloud server. It demostrates how to use the APIs in this SDK


### Running demo

```
# build and install  SDK first
#
# cd <convertlabsdk>
# gem build convertlabsdk.gemspec
# gem install
#
# then
#

bundle install

# set CLAB APPID and SECRET in envronment variables
export CLAB_APPID=<appid>
export CLAB_SECRET=<secret>

#
# review the setting in config/config.yml for database configuration
# defaults to dev.sqlite3 in current directory
#

ruby bin/sync_customer.rb

# 
# if using jruby and warbler, a self-contained executable jar can be created
# 
# warbler 2.0 is required for jruby 9000
#

gem install warbler 
warble
java -jar sync_customer.jar


```