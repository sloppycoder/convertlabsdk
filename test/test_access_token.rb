# encoding: utf-8
require 'helper'

class TestAccessToken < MiniTest::Test
  
  def test_can_get_a_valid_access_token
    VCR.use_cassette('test_access_token_01', record: vcr_record_mode) do
      refute_nil app_client.access_token
    end
  end

  def test_can_get_a_new_token_after_expire_old_token
    VCR.use_cassette('test_access_token_02', record: vcr_record_mode) do
      old_token = app_client.access_token
      refute_nil old_token

      old_token2 = app_client.access_token
      assert_equal old_token, old_token2

      app_client.expire_token!
      new_token = app_client.access_token
      refute_nil new_token

      refute_equal old_token, new_token 
    end
  end

  def test_incorrect_credentials_causes_access_token_error
    VCR.use_cassette('test_access_token_03', record: vcr_record_mode) do
      old_secret = app_client.secret
      app_client.secret = 'bogus'
      
      assert_raises ConvertLab::AccessTokenError do 
        app_client.new_access_token
      end

      app_client.secret = old_secret
    end
  end
end
