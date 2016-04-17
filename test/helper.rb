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

require 'test/unit'
require 'shoulda'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'convertlabsdk'

class Test::Unit::TestCase
end

require 'rest-client'
require 'byebug'
require 'webmock'
require 'vcr'

# RestClient.log = 'stdout'

# VCR config helpers

# def vcr_configure_sensitive_data(config)
#   config.filter_sensitive_data('APPID') do |interaction|
#     byebug
#     uri_param_value interaction.request.uri, 'appid'
#   end
#   config.filter_sensitive_data('SECRET') do |interaction|
#     uri_param_value interaction.request.uri, 'secret'
#   end
#   config.filter_sensitive_data('ACCESSTOKEN') do |interaction|
#     uri_param_value interaction.request.uri, 'access_token'
#   end
# end

# def uri_param_value(url, key)
#   CGI.parse(URI.parse(url).query)[key].first
# end

# sometimes it's handy to disable VCR to go server directly
def disable_vcr?
  env = ENV['NO_VCR']
  env && %w(yes 1 true).include?(env.downcase)
end

def vcr_record_mode
  mode = ENV['VCR_MODE']
  if mode && !mode.empty?
    mode.downcase.to_sym
  else
    :once
  end
end

VCR.configure do |config|
  config.cassette_library_dir = 'test/vcr_cassettes'
  config.hook_into :webmock 
end

if disable_vcr?
  VCR.turn_off!(ignore_cassettes: true)
  WebMock.allow_net_connect!
end

# end of VCR config helper

require 'standalone_migrations'

# rubocop:disable Style/GlobalVars
def app_client
  url = ENV['CLAB_URL'] || 'http://api.51convert.cn'
  $app_client ||= ConvertLab::AppClient.new url, ENV['CLAB_APPID'], ENV['CLAB_SECRET']
end 
# rubocop:enable Style/GlobalVars
