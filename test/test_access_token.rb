# encoding: utf-8
require 'helper'

class TestAccessToken < Test::Unit::TestCase
  
  should '01 get a valid access token' do
    VCR.use_cassette('test_new_access_token_01', record: vcr_record_mode) do
      assert_not_nil app_client.access_token
    end
  end

  should '02 get a different token after expiring the old one' do
    VCR.use_cassette('test_new_access_token_02', record: vcr_record_mode) do
      old_token = app_client.access_token
      assert_not_nil old_token

      old_token2 = app_client.access_token
      assert_equal old_token, old_token2

      app_client.expire_token!
      new_token = app_client.access_token
      assert_not_nil new_token

      assert_not_equal old_token, new_token 
    end
  end

  should '03 incorrect credentials will cause an AccessTokenError' do
    VCR.use_cassette('test_new_access_token_03', record: vcr_record_mode) do
      old_secret = app_client.secret
      app_client.secret = 'bogus'
      
      assert_raise ConvertLab::AccessTokenError do 
        app_client.new_access_token
      end

      app_client.secret = old_secret
    end
  end
end
