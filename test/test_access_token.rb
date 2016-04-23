# encoding: utf-8

require_relative 'helper'

class TestAccessToken < MiniTest::Test
  attr_accessor :app_client

  def setup
    self.app_client = ConvertLab::AppClient.new
  end

  def test_can_get_a_valid_access_token
    VCR.use_cassette('test_access_token_01') do
      refute_nil app_client.access_token
    end
  end

  def test_incorrect_credentials_causes_access_token_error
    VCR.use_cassette('test_access_token_02') do
      old_secret = app_client.secret
      app_client.secret = 'bogus'
      
      assert_raises ConvertLab::AccessTokenError do 
        app_client.access_token!
      end

      app_client.secret = old_secret
    end
  end
end
