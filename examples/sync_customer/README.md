## Sync customer demo program

This is a simple program that upload customer infomration into ConvertLab cloud server. It demostrates how to use the APIs in this SDK


### Running demo

```
bundle install

# set CLAB APPID and SECRET in envronment variables
export CLAB_APPID=<appid>
export CLAB_SECRET=<secret>

#
# make sure to change the SDK path in Gemfile and sync_custoemr.rb 
# if this script is copied to other directory
#
# review the setting in db/config.yml for database configuration
# defaults to dev.sqlite3 in current directory
#
ruby sync_customer.rb


```