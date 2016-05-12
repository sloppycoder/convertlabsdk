# encoding: utf-8

require_relative 'helper'

class TestAccessToken < MiniTest::Test
  attr_accessor :app_client

  init_test_db('development')

  def setup
    self.app_client = ConvertLab::AppClient.new(shared_token: true)
  end

  def test_child_processes_share_the_same_token
    skip "Fork does not work on Windows" if Gem.win_platform?
    VCR.use_cassette('test_access_token_04') do
      parent_token = app_client.access_token
      (1..5).each do
        Process.fork do
          token1 = app_client.access_token
          assert token1 == parent_token
        end
      end

      Process.wait
    end
  end
end
