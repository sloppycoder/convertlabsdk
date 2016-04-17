# encoding: utf-8
require 'helper'

class TestSyncedObject < Test::Unit::TestCase
  
  def setup
    StandaloneMigrations::Configurator.new.config_for_all
    ActiveRecord::Base.establish_connection
    ConvertLab::SyncedObject.destroy_all
  end

  should 'new ChannelAccount record can be retrieved as SyncedObject' do
    ext_id = '123123123'
    obj_id = 11112222
    ch = ConvertLab::SyncedChannelAccount.new
    ch.link_ext_obj 'test_channel', 'ext_type', ext_id
    ch.link_obj obj_id
    ch.save

    obj = ConvertLab::SyncedObject.find(ch.id)

    assert_equal obj.ext_id, ext_id
    assert_equal obj.clab_type, 'channelaccount'
    assert_equal obj.clab_id, obj_id
  end

  should 'external object attributes must be present or validation will fail' do
    ch = ConvertLab::SyncedChannelAccount.new
    assert_raise ActiveRecord::RecordInvalid do
      ch.save!
    end
  end

  should 'lock should work on unlocked record and record that has a stale lock' do
    ch = ConvertLab::SyncedChannelAccount.new
    ch.link_ext_obj 'my_channel', 'sales_order', '999888'
    ch.save

    assert_true ch.lock # 1st time lock should suceed
    assert_false ch.lock # 2nd time lock should fail

    ch.locked_at = Time.now - 7200 
    assert_true ch.lock # lock suceed when lock is stale

    ch.unlock
    assert_false ch.is_locked
  end

  should 'after update need_sync? should return true until after sync_success is called' do
    customer = ConvertLab::SyncedCustomer.create(ext_channel: 'my_channel', ext_type: 'customer', 
                                                 ext_id: '112233444', ext_last_update: Time.now - 1800,
                                                 sync_type: :SYNC_UP)

    assert_equal customer.last_sync, ConvertLab::DUMMY_TIMESTAMP
    assert_true customer.need_sync?

    customer.sync_success
    
    assert_not_equal customer.last_sync, ConvertLab::DUMMY_TIMESTAMP
    assert_false customer.need_sync?
  end

  should 'ignored record does not need to be synced' do
    customer = ConvertLab::SyncedCustomer.create(ext_channel: 'my_channel', ext_type: 'customer', 
                                                 ext_id: '112233444', ext_last_update: Time.now - 1800,
                                                 sync_type: :SYNC_UP)

    assert_equal customer.last_sync, ConvertLab::DUMMY_TIMESTAMP
    assert_true customer.need_sync?

    customer.is_ignored = true
    assert_false customer.need_sync?    
  end

  should 'sync should be skipped after too many (10) errors ' do
    customer = ConvertLab::SyncedCustomer.create(ext_channel: 'my_channel', ext_type: 'customer', 
                                                 ext_id: '112233444', ext_last_update: Time.now - 1800,
                                                 sync_type: :SYNC_UP)

    assert_true customer.need_sync?

    (1..ConvertLab::MAX_SYNC_ERR).each do 
      customer.sync_failed
    end

    assert_false customer.need_sync?    
  end
end
