# encoding: utf-8

require_relative 'helper'

class TestDeal < MiniTest::Test
  attr_accessor :app_client

  def setup
    self.app_client = ConvertLab::AppClient.new
  end

  def test_deal_can_be_created_updated
    deal_detail = { channelAccount: 'TEST_CHANNEL', channelType: 'sales_order', externalId: '12234',
                    customerId: '531', targetId: '531', source: 'TEST_CHANNEL', attr1: 'headache' }
    VCR.use_cassette('test_deal_01') do
      deal = app_client.deal.post(deal_detail)
      refute_nil deal
      assert_equal deal['externalId'], deal_detail[:externalId]

      deal2 = app_client.deal.put(deal['id'], attr1: 'happy')
      assert_equal deal2['attr1'], 'happy'

      app_client.deal.delete deal['id']
    end
  end
end
