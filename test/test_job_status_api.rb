# encoding: utf-8

require_relative 'helper'

class TestJobStatus < MiniTest::Test

  adapter = RUBY_PLATFORM == 'java' ? 'jdbcsqlite3' : 'sqlite3'
  ActiveRecord::Base.establish_connection(adapter: adapter, database: ':memory:')
  ActiveRecord::Migrator.migrate(File.dirname(__FILE__) + '/../db/migrate/')

  def test_job_status_api
    job = ConvertLab.job_status('test_job')
    assert job.new?

    job.last_sync = Time.now
    job.save!

    job2 = ConvertLab.job_status('test_job')
    assert_equal job.id, job2.id
    refute job2.new?
  end
end
