# encoding: utf-8

require 'active_record'

class CreateAccessToken < ActiveRecord::Migration
  def change
    create_table :access_tokens do |t|
      t.string :token, limit: 64
      t.timestamp :expires_at
      t.boolean :is_locked, default: false  
      t.string :locked_by
    end
  end
end
