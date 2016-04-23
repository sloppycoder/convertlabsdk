# encoding: utf-8

require_relative 'helper'

class TestSyncedObject < MiniTest::Test
  attr_reader :data
  
  adapter = RUBY_PLATFORM == 'java' ? 'jdbcsqlite3' : 'sqlite3'  
  ActiveRecord::Base.establish_connection(adapter: adapter, database: ':memory:')
  ActiveRecord::Migrator.migrate(File.dirname(__FILE__) + '/../db/migrate/')    

  def setup
    ConvertLab::SyncedObject.destroy_all
  end

  CHANNEL = 'TEST_CHANNEL'.freeze
  CUSTOMER = { ext_channel: 'RBSDK_TEST_CHANNEL', ext_type: 'customer', ext_id: 'A1234' }.freeze
  CLAB_CUSTOMER = { 'id' => 1000, 'lastUpdated' => '2016-04-20T16:48:50Z' }.freeze

  def test_sync_new_customer_to_clab
    new_customer = CUSTOMER.dup
    new_customer.merge(name: 'gurulin', mobile: '133133133')

    api_client = Minitest::Mock.new
    api_client.expect :post, CLAB_CUSTOMER, [new_customer]

    ConvertLab::SyncedCustomer.sync(api_client, new_customer, CUSTOMER)

    api_client.verify
  end

  def test_sync_update_existing_customer_in_clab
    clab_id = CLAB_CUSTOMER['id']
    new_customer = CUSTOMER.dup
    new_customer.merge(name: 'gurulin', mobile: '133133133')

    api_client = Minitest::Mock.new
    api_client.expect :put, CLAB_CUSTOMER, [clab_id, new_customer]

    ConvertLab::SyncedCustomer.sync(api_client, new_customer, CUSTOMER.merge(clab_id: clab_id))

    api_client.verify
  end
end
