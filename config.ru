# encoding: utf-8

LIB = File.dirname(__FILE__) + '/lib'
$LOAD_PATH.unshift LIB unless $LOAD_PATH.include?(LIB)

require 'active_record'
require 'convertlabsdk'
require 'convertlabsdk/server'
require 'resque'
require 'resque/server'

ConvertLab.database_yml = 'config/database.yml'
ConvertLab.establish_connection

use Rack::ShowExceptions

run Rack::URLMap.new(
  '/syncer' => ConvertLab::Server.new,
  '/resque' => Resque::Server.new
)
