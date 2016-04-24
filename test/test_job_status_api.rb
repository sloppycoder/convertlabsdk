# encoding: utf-8

require_relative 'helper'

class TestJobStatus < MiniTest::Test

  init_test_db

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
