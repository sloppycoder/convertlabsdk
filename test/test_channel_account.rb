# encoding: utf-8
# rubocop:disable Lint/HandleExceptions:
# rubocop:disable Metrics/MethodLength:

require_relative 'helper'

class TestChannelAccount < MiniTest::Test
  attr_accessor :app_client

  def setup
    self.app_client = ConvertLab::AppClient.new
  end

  def test_channel_account_can_be_created_and_deleted
    channel_type = 'RBSDK_TEST_CHANNEL'
    cust1 = Random.rand(2000000..4000000)
    channel_acc1 = { type: channel_type, customerId: cust1, userId: "u#{cust1}" }

    VCR.use_cassette('test_channel_account_01') do
      # creating new object will return its id when success
      id = app_client.channel_account.post(channel_acc1)['id']
      refute_nil id

      # nil is returned for a successful deletion
      assert_nil app_client.channel_account.delete(id)

      # retrieve with non-existent id throws internal exception
      # instead of return 404. is it a bug?
      assert_raises RestClient::InternalServerError do 
        app_client.channel_account.get(id)
      end
    end
  end

  def test_search_using_filter_returns_matching_result
    # we use a fix customer id here because the id will be part of the url parameters
    # having a random number can cause problem with VCR uri matching
    channel_type = 'RBSDK_TEST_CHANNEL'
    cust2 = 3021200
    tag_line = 'Feel the Bern!'
    bern1 = { type: channel_type, customerId: cust2, userId: "u#{cust2}", name: 'bernie' }
    bern3 = { type: channel_type, customerId: cust2, userId: "u#{cust2}", name: 'bernie', att1: tag_line }

    VCR.use_cassette('test_channel_account_02') do
      # channel account allow create record with same attributes. bug?
      id1 = app_client.channel_account.post(bern1)['id']
      id2 = app_client.channel_account.post(bern1)['id']
      refute_equal id1, id2

      # create a record with different attributes
      id3 = app_client.channel_account.post(bern3)['id']
      refute_nil id3

      o = app_client.channel_account.find(att1: tag_line, userId: "u#{cust2}")
      # only matches bern3
      assert_equal o.size, 1

      o = app_client.channel_account.find(userId: "u#{cust2}")
      # should be bern1 twice plus bern3 == 3
      assert_equal o.size, 3

      [id1, id2, id3].each do |id|
        begin
          app_client.channel_account.delete(id)
        rescue RestClient::InternalServerError
        end
      end
    end
  end

  def test_attributes_can_be_updated
    # we use a fix customer id here because the id will be part of the url parameters
    # having a random number can cause problem with VCR uri matching
    channel_type = 'RBSDK_TEST_CHANNEL'
    cust3 = Random.rand(2000000..4000000)
    old_tag_line = 'Make America great again.'
    new_tag_line =  "You're fired!"
    trump = { type: channel_type, customerId: cust3, userId: "u#{cust3}", att1: old_tag_line }
    trump2 = { att1: new_tag_line }

    VCR.use_cassette('test_channel_account_03') do
      id = app_client.channel_account.post(trump)['id']
      refute_nil id

      app_client.channel_account.put(id, trump2)
      assert_equal app_client.channel_account.get(id)['att1'], new_tag_line

      # delete what we just created so that we can run the test again
      begin
        app_client.channel_account.delete(id)
      rescue RestClient::InternalServerError
      end
    end
  end
end
