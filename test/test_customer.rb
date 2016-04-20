# encoding: utf-8
# rubocop:disable Lint/HandleExceptions:

require 'helper'

class TestCustomer < MiniTest::Test
  # always get a new token for test case so that get access token is record by VCR 
  # then this case can be run independently with running test_access_token first
  def setup
    app_client.expire_token!
  end

  def test_create_customer_with_same_mobile_number_will_return_an_existing_record
    mobile_no = '13911223366'
    guru = { name: 'guru', mobile: mobile_no, email: 'guru@jungle.cc', external_id: 'XYZ1234' }
    fake_guru = { name: 'fake guru', mobile: mobile_no, email: 'guru@jungle.co', external_id: 'XYZ1235' }

    VCR.use_cassette('test_customer_01') do
      # creating new object will return its id when success
      id = app_client.customer.post(guru)['id']
      refute_nil id

      # customer enforce uniqueness of mobile phone
      id2 = app_client.customer.post(fake_guru)['id']
      assert_equal id, id2

      assert_equal app_client.customer.find(mobile: mobile_no)['records'], 1

      # nil is returned for a successful deletion
      assert_nil app_client.customer.delete(id)

      # retrieve with non-existent id throws internal exception
      # instead of return 404. is it a bug?
      begin
        app_client.customer.get(id)
      rescue RestClient::InternalServerError
      end
    end
  end

  def test_customer_attributes_can_be_updated
    mobile_no = '13911223366'
    guru = { name: 'guru', mobile: mobile_no, email: 'guru@jungle.cc', external_id: 'XYZ1234' }

    VCR.use_cassette('test_customer_02') do
      # creating new object will return its id when success
      id = app_client.customer.post(guru)['id']
      refute_nil id

      new_attr = { wechat: 'jackma' }
      updated = app_client.customer.put(id, new_attr)
      assert_equal updated['wechat'], 'jackma'

      # nil is returned for a successful deletion
      assert_nil app_client.customer.delete(id)
    end
  end
end
