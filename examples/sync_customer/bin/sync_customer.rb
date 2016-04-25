# encoding: utf-8
#
#
# Demo program to sync customer data to the cloud
#
require 'convertlabsdk'
require 'yaml'

logger = Logger.new STDOUT
logger.level = Logger::DEBUG
ConvertLab::logger = logger

def config
  e = ARGV.first || 'development'
  e += '_jruby' if RUBY_PLATFORM == 'java' 
  @config ||= YAML::load(File.open('config/config.yml'))[e]
end

def app_client
  url = config['app']['url'] || 'http://api.51convert.cn'
  @app_client ||= ConvertLab::AppClient.new(url: url, appid: ENV['CLAB_APPID'], secret: ENV['CLAB_SECRET'])
end

def testdata
  return @data if @data

  require 'csv'
  csv_source = %(
orderNumber,isMember,membershipLevel,membershipNo,mobile,name,last_update
10001,true,silver,A1234,139112233,guru lin,2016-01-01
10002,true,gold,A1111,133123123,stefan liu,2016-01-01
10001,true,gold,A1234,139112233,guru lin,2016-01-02
10003,true,platinum,A8888,133333333,jack ma,2016-01-02
)
  @data = []
  CSV.parse(csv_source, skip_blanks: true, headers: true) do |row|
    @data << row.to_hash
  end
  @data
end

def intervals
  testdata.collect { |row| row['last_update'] }.uniq.sort
end

def order_details(day)
  testdata.select { |r| r['last_update'] == day }
end

if ARGV.at(1) == 'debug' 
  if RUBY_PLATFORM == 'java'
    require 'pry'
    binding.pry
  elsif RUBY_VERSION.index('2.') == 0
    require 'byebug'
    byebug
  else
    require 'debugger'
    debugger
  end
end

ActiveRecord::Base.establish_connection(config['db'])
mig_path = File.expand_path(File.dirname(__FILE__) + '/../db/migrate')
ActiveRecord::Migrator.migrate(mig_path)

# ConvertLab::SyncedObject.destroy_all
channel = 'TEST_CHANNEL'

#
# main logic begins here
#
intervals.each do |since|
  logger.info "starting current batch at #{since}"

  order_details(since).each do |order|
    # identify linked clab record first
    # this is not implmented in SDK itself since the match logic can involve multiple
    # steps and cannot be generalize
    clab_cust = app_client.customer.find(mobile: order['mobile'])['rows'].first || {}
    # add data transformation and lookup
    customer = order
    # channelaccount = extract_channle_info(order)
    # customerevent = extract_event_info(order)
    # clab_channel_id = app_client.channelaccount.find(blah) 
    
    # invoke helper method to perform sync up to clab cloud service
    ext_id = order['membershipNo']
    ConvertLab::SyncedCustomer.sync app_client.customer, customer, 
                                    ext_channel: channel, ext_type: 'buyer', ext_id: ext_id, 
                                    clab_id: clab_cust['id']
    # ConvertLab::SyncedChannelAccount.sync_up channel, 'buyer' ext_id, 
    #                                          clab_channel_id, app_client.channelaccount, channelaccount
    # ConvertLab::SyncedCustomer.sync_up channel, type, 'order', nil, app_client.customerevent, customerevent
  end

  logger.info "done with current batch at #{since}"
end

# this prevent the container from being stopped 
sleep 1000000 if ARGV.first == 'docker'
