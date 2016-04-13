# encoding: utf-8

require 'helper'
require 'byebug'
require 'yaml'

#
# TODO:
#   1. enable vcr gem for offline testing
#   2. use rspect or minitest?
#
class TestConvertlabSdk < Test::Unit::TestCase
  should 'get a valid access token' do
    assert_not_nil create_app_client.access_token
  end

  should 'should get a new token after expiring the old one' do
    app_client = create_app_client
    old_token = app_client.access_token
    assert_not_nil old_token

    old_token2 = app_client.access_token
    assert_equal old_token, old_token2

    app_client.expire_token!
    new_token = app_client.access_token
    assert_not_nil new_token

    # will this be valid once vcr is enabled?
    assert_not_equal old_token, new_token 
  end
end

def create_app_client
  url = ENV['CLAB_URL'] || 'http://api.51convert.cn'
  ConvertLab::AppClient.new url, appid: ENV['CLAB_APPID'], secret: ENV['CLAB_SECRET']
end 