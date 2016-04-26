# encoding: utf-8

require 'active_record'

class CreateSyncedObjects < ActiveRecord::Migration
  def change
    create_table :synced_objects do |t|      
      # single table inheritence
      t.string :type, limit: 64

      # clab attributes
      t.integer :clab_id
      t.string :clab_type, limit: 32
      t.timestamp :clab_last_update

      # ext party attributes
      t.string :ext_channel, limit: 32
      t.string :ext_type, limit: 32
      t.string :ext_id, limit: 48
      t.timestamp :ext_last_update

      # SDK attributes for house keeping
      t.integer :sync_type, default: 0 
      t.integer :err_count, default: 0
      t.timestamp :last_sync
      t.timestamp :last_err
      t.string :err_msg
      t.boolean :is_ignored, default: false
      t.boolean :is_locked, default: false  
      t.timestamp :locked_at
    end
  end
end
