# encoding: utf-8

require_relative 'helper'

class TestAccessToken < MiniTest::Test
  attr_accessor :app_client

  init_test_db

  def setup
    self.app_client = ConvertLab::AppClient.new(shared_token: true)
  end

  def test_can_get_a_valid_access_token
    VCR.use_cassette('test_access_token_01') do
      refute_nil app_client.access_token
    end
  end

  def test_incorrect_credentials_causes_access_token_error
    VCR.use_cassette('test_access_token_02') do
      # there is no need for token_store to be made public accessible,
      # we do a hack here for the sake of testing
      token_store = app_client.instance_variable_get('@token_store')
      old_secret = token_store.secret
      token_store.secret = 'bogus'
      
      assert_raises ConvertLab::AccessTokenError do 
        app_client.update_token
      end

      token_store.secret = old_secret
    end
  end

  def test_can_get_a_new_token_after_expire_old_token
    VCR.use_cassette('test_access_token_03') do
      old_token = app_client.access_token
      refute_nil old_token

      old_token2 = app_client.access_token
      assert_equal old_token, old_token2

      app_client.update_token
      new_token = app_client.access_token
      refute_nil new_token

      refute_equal old_token, new_token
    end
  end
end
