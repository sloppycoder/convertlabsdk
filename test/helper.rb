# encoding: utf-8

require 'simplecov'

module SimpleCov::Configuration
  def clean_filters
    @filters = []
  end
end

SimpleCov.configure do
  clean_filters
  load_profile 'test_frameworks'
end

ENV['COVERAGE'] && SimpleCov.start do
  add_filter '/.rvm/'
  add_filter '/.rbenv/'
end

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end

# VCR config helpers
require 'webmock'
require 'vcr'
require 'json'

def vcr_configure_sensitive_data(config)
  config.filter_sensitive_data('APPID') do |interaction|
    uri_param_value interaction.request.uri, 'appid'
  end
  config.filter_sensitive_data('SECRET') do |interaction|
    uri_param_value interaction.request.uri, 'secret'
  end
  config.filter_sensitive_data('ACCESSTOKEN') do |interaction|
    uri_param_value interaction.request.uri, 'access_token'
  end
  config.filter_sensitive_data('ACCESSTOKEN') do |interaction|
    if interaction.request.uri.include?('/security/accesstoken')
      begin
        response = JSON.parse(interaction.response.body)
        # only mask out part of the token to retain some randomness
        # of the string. otherwise test case can fail
        response['error_code'] == 0 ? response['access_token'][-8..-1] : nil
      rescue JSON::ParserError
      end
    end
  end
end

def uri_param_value(url, key)
  CGI.parse(URI.parse(url).query)[key].first
end

# sometimes it's handy to disable VCR to go server directly
def disable_vcr?
  env = ENV['NO_VCR']
  env && %w(yes 1 true).include?(env.downcase)
end

VCR.configure do |config|
  config.cassette_library_dir = File.dirname(__FILE__) + '/vcr_cassettes'
  config.hook_into :webmock 
  config.default_cassette_options = {
    match_requests_on: [:method, VCR.request_matchers.uri_without_param(:access_token, :appid, :secret)]
  }
  vcr_configure_sensitive_data(config)
end

if disable_vcr?
  VCR.turn_off!(ignore_cassettes: true)
  WebMock.allow_net_connect!
end
# end of VCR config helper

def init_test_db
  adapter = RUBY_PLATFORM == 'java' ? 'jdbcsqlite3' : 'sqlite3'
  ActiveRecord::Base.establish_connection(adapter: adapter, database: ':memory:')
  silence_stream(STDOUT) do
    ActiveRecord::Migrator.migrate(File.dirname(__FILE__) + '/../db/migrate/')
  end
end

require 'minitest'
require 'minitest/autorun'
require 'minitest/profile'
require 'minitest/reporters'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'convertlabsdk'

class MiniTest::Test
end

MiniTest::Reporters.use!
MiniTest.autorun
