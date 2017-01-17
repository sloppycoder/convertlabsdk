# encoding: utf-8

require 'minitest'
require 'minitest/autorun'
require 'minitest/profile'
require 'minitest/reporters'
require 'rack/test'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'convertlabsdk'
require 'convertlabsdk/server'

def init_test_db2(env = 'memory')
  ConvertLab.database_yml = File.dirname(__FILE__) + '/../config/database.yml'
  ConvertLab.establish_connection(env)
  silence_stream(STDOUT) do
    ActiveRecord::Migrator.migrate(File.dirname(__FILE__) + '/../db/migrate/')
  end
end

class MiniTest::Test
end

MiniTest::Reporters.use!
MiniTest.autorun
