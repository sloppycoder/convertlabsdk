# encoding: utf-8
# rubocop:disable Lint/HandleExceptions:

require 'helper'

class TestCustomer < Test::Unit::TestCase
  mobile_no = '13911223366'
  guru = { name: 'guru', mobile: mobile_no, email: 'guru@jungle.cc', external_id: 'XYZ1234' }
  fake_guru = { name: 'fake guru', mobile: mobile_no, email: 'guru@jungle.co', external_id: 'XYZ1235' }

  # always get a new token for test case so that get access token is record by VCR 
  # then this case can be run independently with running test_access_token first
  def setup
    app_client.expire_token!
  end

  should '01 create customer with same mobile number will return the existing record' do 
    VCR.use_cassette('test_customer_01', record: vcr_record_mode) do
      # creating new object will return its id when success
      id = app_client.customer.post(guru)['id']
      assert_not_nil id

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

  should '02 attributes can be updated for existing customer' do 
    VCR.use_cassette('test_customer_02', record: vcr_record_mode) do
      # creating new object will return its id when success
      id = app_client.customer.post(guru)['id']
      assert_not_nil id

      new_attr = { wechat: 'jackma' }
      updated = app_client.customer.put(id, new_attr)
      assert_equal updated['wechat'], 'jackma'

      # nil is returned for a successful deletion
      assert_nil app_client.customer.delete(id)
    end
  end
end
