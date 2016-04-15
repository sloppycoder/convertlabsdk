# encoding: utf-8
# rubocop:disable Lint/HandleExceptions:

require 'helper'

class TestChannelAccount < Test::Unit::TestCase
  channel_type = 'RBSDK_TEST_CHANNEL'

  should '01 can be created then deleted then cannot be retrieved again' do 
    cust1 = Random.rand(2000000..4000000)
    channel_acc1 = { type: channel_type, customerId: cust1, userId: "u#{cust1}" }

    VCR.use_cassette('test_channel_account_01', record: vcr_record_mode) do
      # creating new object will return its id when success
      id = app_client.channel_account.post(channel_acc1)['id']
      assert_not_nil id

      # nil is returned for a successful deletion
      assert_nil app_client.channel_account.delete(id)

      # retrieve with non-existent id throws internal exception
      # instead of return 404. is it a bug?
      assert_raise RestClient::InternalServerError do 
        app_client.channel_account.get(id)
      end
    end
  end

  should '02 return search result based on filter' do 
    # we use a fix customer id here because the id will be part of the url parameters
    # having a random number can cause problem with VCR uri matching
    cust2 = 3021299
    tag_line = 'Feel the Bern!'
    bern1 = { type: channel_type, customerId: cust2, userId: "u#{cust2}", name: 'bernie' }
    bern3 = { type: channel_type, customerId: cust2, userId: "u#{cust2}", name: 'bernie', att1: tag_line }

    VCR.use_cassette('test_channel_account_02', record: vcr_record_mode) do
      # channel account allow create record with same attributes. bug?
      id1 = app_client.channel_account.post(bern1)['id']
      id2 = app_client.channel_account.post(bern1)['id']
      assert_not_equal id1, id2

      # create a record with different attributes
      id3 = app_client.channel_account.post(bern3)['id']
      assert_not_nil id3

      o = app_client.channel_account.find(att1: tag_line, userId: "u#{cust2}")
      # only matches bern3
      assert_equal o.size, 1

      o = app_client.channel_account.find(userId: "u#{cust2}")
      # should be bern1 twice plus bern3 == 3
      assert_equal o.size, 3

      [id1, id2, id3].each do |id|
        begin
          app_client.channel_account.get(id)
        rescue RestClient::InternalServerError
        end
      end
    end
  end

  should '03 allow update of attributes' do 
    # we use a fix customer id here because the id will be part of the url parameters
    # having a random number can cause problem with VCR uri matching
    cust3 = Random.rand(2000000..4000000)
    old_tag_line = 'Make America great again.'
    new_tag_line =  "You're fired!"
    trump = { type: channel_type, customerId: cust3, userId: "u#{cust3}", att1: old_tag_line }
    trump2 = { att1: new_tag_line }

    VCR.use_cassette('test_channel_account_03', record: vcr_record_mode) do
      id = app_client.channel_account.post(trump)['id']
      assert_not_nil id

      app_client.channel_account.put(id, trump2)
      assert_equal app_client.channel_account.get(id)['att1'], new_tag_line

      # delete what we just created so that we can run the test again
      begin
        app_client.channel_account.get(id)
      rescue RestClient::InternalServerError
      end
    end
  end
end
