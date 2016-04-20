# encoding: utf-8

require 'helper'

class TestCustomerEvent < MiniTest::Test
  # always get a new token for test case so that get access token is record by VCR 
  # then this case can be run independently with running test_access_token first
  def setup
    app_client.expire_token!
  end

  def test_customer_event_can_be_created_updated
    order_event = { channelAccount: 'TEST_CHANNEL', channelType: 'sales_order', externalId: '12234', 
                    customerId: '531', targetId: '531', source: 'TEST_CHANNEL', attr1: 'headache' }
    VCR.use_cassette('test_customer_event_01') do
      event = app_client.customer_event.post(order_event)
      refute_nil event
      assert_equal event['externalId'], order_event[:externalId]

      event2 = app_client.customer_event.put(event['id'], attr1: 'happy')
      assert_equal event2['attr1'], 'happy'

      app_client.customer_event.delete event['id']
    end
  end
end
