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

require 'webmock'
require 'vcr'
VCR.configure do |config|
  config.cassette_library_dir = 'test/vcr_cassettes'
  config.hook_into :webmock 
  # TODO: restore filter logic 
  # config.filter_sensitive_data('<CREDENTIALS>') do |interaction|
  #   u = interaction.request.uri
  #   i = u.index('appid=') # ?appid=blah&secret=blah&grant_type
  #   u[i..1000] if i
  # end
end

# sometimes it's handy to disable VCR to go server directly
def disable_vcr?
  env = ENV['NO_VCR']
  env && %w(yes 1 true).include?(env.downcase)
end

if disable_vcr?
  VCR.turn_off!(ignore_cassettes: true)
  WebMock.allow_net_connect!
end

def vcr_record_mode
  mode = ENV['VCR_MODE']
  if mode && !mode.empty?
    mode.downcase.to_sym
  else
    :once
  end
end

# rubocop:disable Style/GlobalVars
def app_client
  url = ENV['CLAB_URL'] || 'http://api.51convert.cn'
  $app_client ||= ConvertLab::AppClient.new url, ENV['CLAB_APPID'], ENV['CLAB_SECRET']
end 
# rubocop:enable Style/GlobalVars

# always helpful when debugging
require 'byebug'
