# encoding: utf-8

LIB = File.dirname(__FILE__) + '/lib'
$LOAD_PATH.unshift LIB unless $LOAD_PATH.include?(LIB)

require 'active_record'
require 'convertlabsdk'
require 'convertlabsdk/server'
require 'resque'
require 'resque/server'
require 'sinatra/base'

use Rack::ShowExceptions

Resque.redis = ENV['REDIS_HOST'] || 'localhost:6379'
ConvertLab.database_yml = 'config/database.yml'
ConvertLab.establish_connection

# insert tab into Resque web console to navigate to syncer
module Resque
  Resque::Server.tabs
  class Server < Sinatra::Base
    get '/syncer' do
      redirect "#{url_prefix}/../syncer"
    end
  end
end

Resque::Server.tabs << 'Syncer'
# end of hacking Resque web

run Rack::URLMap.new(
  '/syncer' => ConvertLab::Server.new,
  '/resque' => Resque::Server.new
)
