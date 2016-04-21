# encoding: utf-8
require 'helper'
require 'logger'

class TestSyncedObject < MiniTest::Test
  
  ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
  ActiveRecord::Migrator.migrate(File.dirname(__FILE__) + '/../db/migrate/')    

  def test_channel_account_record_can_be_retrieved_as_synced_object
    ext_id = '123123123'
    obj_id = 11112222
    ch = ConvertLab::SyncedChannelAccount.new
    ch.link_ext_obj 'test_channel', 'ext_type', ext_id
    ch.clab_id = obj_id
    ch.save

    obj = ConvertLab::SyncedObject.find(ch.id)

    assert_equal obj.ext_id, ext_id
    assert_equal obj.clab_type, 'channelaccount'
    assert_equal obj.clab_id, obj_id
  end

  def test_validation_fails_when_external_object_attributes_not_present
    ch = ConvertLab::SyncedChannelAccount.new
    assert_raises ActiveRecord::RecordInvalid do
      ch.save!
    end
  end

  def test_lock_works_on_unlocked_record_or_record_with_stale_lock
    ch = ConvertLab::SyncedChannelAccount.new
    ch.link_ext_obj 'my_channel', 'sales_order', '999888'
    ch.save

    assert ch.lock # 1st time lock should suceed
    refute ch.lock # 2nd time lock should fail

    ch.locked_at = Time.now - 7200 
    assert ch.lock # lock suceed when lock is stale

    ch.unlock
    refute ch.is_locked
  end

  def test_need_sync_returns_true_after_sync_success_is_called
    customer = ConvertLab::SyncedCustomer.create(ext_channel: 'my_channel', ext_type: 'customer', 
                                                 ext_id: '112233444', ext_last_update: Time.now - 1800,
                                                 sync_type: :SYNC_UP)

    # clab_id nil will trigger sync
    customer.update clab_type: 'customer', clab_id: 11223344

    assert_equal customer.last_sync, ConvertLab::DUMMY_TIMESTAMP
    assert customer.need_sync?

    customer.sync_success
    
    refute_equal customer.last_sync, ConvertLab::DUMMY_TIMESTAMP
    refute customer.need_sync?
  end

  def test_need_sync_returns_false_for_ignored_record
    customer = ConvertLab::SyncedCustomer.create(ext_channel: 'my_channel', ext_type: 'customer', 
                                                 ext_id: '112233444', ext_last_update: Time.now - 1800,
                                                 sync_type: :SYNC_UP)

    assert_equal customer.last_sync, ConvertLab::DUMMY_TIMESTAMP
    assert customer.need_sync?

    customer.is_ignored = true
    refute customer.need_sync?    
  end

  def test_need_sync_returns_false_for_record_has_max_sync_err
    customer = ConvertLab::SyncedCustomer.create(ext_channel: 'my_channel', ext_type: 'customer', 
                                                 ext_id: '112233444', ext_last_update: Time.now - 1800,
                                                 sync_type: :SYNC_UP)

    assert customer.need_sync?

    # sync_failed will print out scary logs
    # disable the logging temporarily
    level = ConvertLab::logger.level
    ConvertLab::logger.level = Logger::ERROR

    (1..ConvertLab::MAX_SYNC_ERR).each do 
      customer.sync_failed
    end

    ConvertLab::logger.level = level

    refute customer.need_sync?    
  end
end
