# encoding: utf-8

HERE = File.dirname(__FILE__)
$LOAD_PATH.unshift HERE unless $LOAD_PATH.include?(HERE)

require 'resque/server'
require 'resque-scheduler'
require 'resque/scheduler/server'

use Rack::ShowExceptions

# Set the AUTH env variable to your basic auth password to protect Resque.
AUTH_PASSWORD = ENV['AUTH']
if AUTH_PASSWORD
  Resque::Server.use Rack::Auth::Basic do |username, password|
    password == AUTH_PASSWORD
  end
end

Resque.redis = ENV['REDIS_HOST'] || 'localhost:6379'
run Rack::URLMap.new '/resque' => Resque::Server.new
