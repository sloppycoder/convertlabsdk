# encoding: utf-8

require 'active_record'

class CreateJobStatus < ActiveRecord::Migration
  def change
    create_table :job_statuses do |t|
      t.string :name, limit: 64
      t.string :status, limit: 16
      t.string :memo, limit: 2000
      t.timestamp :last_sync
    end
  end
end
