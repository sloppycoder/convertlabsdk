# encoding: utf-8
require_relative 'server_helper'

class TestServer < MiniTest::Test
  include Rack::Test::Methods

  init_test_db2

  def app
    ConvertLab::Server
  end

  def test_slash_redirect_to_datasource
    get '/'
    assert last_response.status == 302
    assert last_response.header['Location'].ends_with?('/datasource')
  end

  def test_datasource_info
    get '/datasource'
    assert last_response.ok?
    assert last_response.body.include?('sqlite3')
  end

  def test_synced_objects
    create_test_data
    get '/syncedobjects'
    assert last_response.ok?
    assert last_response.body.include?('11122')
  end

  def create_test_data
    ch = ConvertLab::SyncedChannelAccount.new
    ch.link_ext_obj 'test_channel', 'ext_type', '123'
    ch.clab_id = 11122
    ch.save
  end
end
