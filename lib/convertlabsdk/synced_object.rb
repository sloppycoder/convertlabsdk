# encoding: utf-8

require 'active_record'
require 'active_support/core_ext'
require 'date'

module ConvertLab
  class JobStatus < ActiveRecord::Base
    # is the JobStatus record new
    # @return [boolean]
    def new?
      last_sync == DUMMY_TIMESTAMP
    end
  end

  # Returns JobStatus record for job_name. A new record will be created if one does not exist
  #
  # @example
  #     job = ConvertLab.job_status('upload_data_job')
  #     if job.new?
  #       initialize_the_job
  #     end
  #
  # @param job_name [String]
  # @return [JobStatus]
  def self.job_status(job_name)
    job = JobStatus.where(name: job_name).first_or_create
    job.last_sync ||= DUMMY_TIMESTAMP
    job
  end


  # Exception indicates error occurred when trying to synchronizate an external object with ConvertLab record
  class SyncError < RuntimeError; end

  #
  # class that facilitate syncing of external objects to ConvertLab cloud APIs.
  # A local data store is required to store mapping between external objects and ConvertLab records
  #
  # This class has 4 child classes. SyncedChannelAccount, SyncedCustomer, SyncedCustomerEvent, SyncedDeal. All have the
  # same APIs. Usage of the APIs are shown in examples below.
  #
  # @example
  #
  #     # to upload an external customer to ConvertLab
  #
  #     ActiveRecord::Base.establish_connection
  #
  #     app_client = init_connection_detail
  #     ext_customer_info = {ext_channel: 'MY_SUPER_STORE', ext_type: 'customer', , ext_id: 'my_customer_id'}
  #     clab_customer = map_ext_customer_to_clab(ext_customer_info)
  #
  #     ConvertLab::SyncedCustomer.sync app_client.customer, clab_customer, ext_customer_info
  #
  # @todo more examples coming soon
  #
  class SyncedObject < ActiveRecord::Base
    include Logging

    validates :ext_channel, :ext_type, :ext_id, presence: true
    enum sync_type: { SYNC_UP: 0, SYNC_DOWN: 1, SYNC_BOTHWAYS: 2 }  
    
    before_save :default_values

    def self.sync(api_client, data, filters)
      f = filters.dup
      clab_id = f.delete(:clab_id)
      f.merge(sync_type: sync_types[:SYNC_UP]) unless filters.key? :sync_type
      sync_obj = where(f).first_or_create
      logger.debug "#{sync_obj} #{sync_obj.ext_obj} <-> #{sync_obj.clab_obj}"
      sync_obj.sync(api_client, data, clab_id)
    end

    def sync(api_client, data, new_clab_id)
      link_clab_obj(new_clab_id)
      t = data['last_update']
      self.ext_last_update = t ? Time.new(t) : DUMMY_TIMESTAMP
      save!
      
      if need_sync?
        do_sync_up(api_client, data)
      else
        logger.debug "#{self} is up to date with #{clab_obj}"
      end
    end

    # rubocop:disable Metrics/CyclomaticComplexity:
    # rubocop:disable Metrics/PerceivedComplexity:


    # Returns true if the record needs to be synchronized. 
    # A record should be synchronized if either of the following is true
    #  the record has never been synchronized before
    #  the record's timestamp is newer than last_sync
    #  the record's err_count has not exceed MAX_SYNC_ERR. currently set to 10
    #
    # @return [Boolean]
    def need_sync?
      if is_ignored || err_count >= MAX_SYNC_ERR
        false
      elsif last_sync == DUMMY_TIMESTAMP
        true
      else
        case sync_type.to_sym
        when :SYNC_UP
          clab_id.nil? || ext_last_update > last_sync
        when :SYNC_DOWN
          ext_obj_id.nil? || clab_last_update > last_sync
        else
          raise SyncError, 'sync mode not supported'
        end
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity:
    # rubocop:enable Metrics/PerceivedComplexity:

    # Mark the record synchronization success
    def sync_success(timestamp = Time.now)
      logger.debug "#{self} sync success"
      self.last_sync = timestamp
      save!
    end

    # Mark the record synchronization failed and increment the error count
    def sync_failed(timestamp = Time.now, msg = '')
      logger.warn "#{self} sync failed with error #{msg}"
      self.last_err = timestamp
      self.err_msg = msg
      self.err_count += 1
      save!
    end

    # Reset record's synchronization status and clear the error count, so it can be synchronized again.
    def sync_reset
      self.last_sync = DUMMY_TIMESTAMP
      self.err_count = 0
      self.err_msg = ''
    end

    # link the record to an external record
    # @param channel [String] external channel
    # @param type [String] external record type
    # @param id [String] external record id
    def link_ext_obj(channel, type, id)
      self.ext_channel = channel
      self.ext_type = type
      self.ext_id = id
    end

    # Link the record to a ConvertLab record
    # @param new_clab_id [Fixnum] ConvertLab record id
    def link_clab_obj(new_clab_id)
      old_clab_id = clab_id
      if old_clab_id != new_clab_id
        # change clab obj will reset sync time
        self.clab_id = new_clab_id
        self.last_sync = DUMMY_TIMESTAMP
        unless old_clab_id.nil?
          logger.warn "#{self} overwriting #{old_clab_id} with #{clab_obj}"
        end
      end
    end

    # Returns string representation of an external object. Used for logging
    # @return [String]
    def ext_obj
      "ext(#{ext_channel}, #{ext_type}, #{ext_id})"
    end

    # Returns string representation of a convert lab object. Used for logging
    # @return [String]
    def clab_obj
      id_string = clab_id ? clab_id : 'new'
      "clab(#{clab_type}, #{id_string})"
    end

    # Returns string representation of the object. Used for logging
    # @return [String]
    def to_s
      t = (type || 'unknown').split(':')[-1]
      i = id ? id.to_s : 'new'
      "#{t}(#{i})"
    end

    # Lock the record. Not in use.
    def lock
      # locking will automatically trigger reload
      # locker older than 1 hour is considered stale
      if !is_locked || (is_locked && locked_at < Time.now - 3600)
        self.is_locked = true
        self.locked_at = Time.now
        save!
      else
        false
      end
    end

    # Unlock the record. Not in use.
    def unlock
      self.is_locked = false
      self.locked_at = nil
      save!
    end

    private

    # Perform the up sync to ConvertLab
    def do_sync_up(api_client, data)
      if clab_id
        # update the linked clab record
        logger.info "#{self} updating #{clab_obj}"
        obj = api_client.public_send('put', clab_id, data)
      else
        # create a new clab record and link it
        logger.info "#{self} creating new clab object"
        obj = api_client.public_send('post', data)
        self.clab_id = obj['id']
        logger.info "#{self} created #{clab_obj}"
      end
      t = obj['lastUpdated']
      self.clab_last_update = t ? DateTime.iso8601(t).to_time : DUMMY_TIMESTAMP
      sync_success
      true
    rescue RuntimeError => e
      sync_fail e.to_s
      false
    end

    # Set default values for some fields
    def default_values
      self.sync_type ||= :SYNC_UP
      self.last_sync ||= DUMMY_TIMESTAMP
      self.clab_type = case type
                       when 'ConvertLab::SyncedChannelAccount'
                         'channelaccount'
                       when 'ConvertLab::SyncedCustomer'
                         'customer'
                       when 'ConvertLab::SyncedCustomerEvent'
                         'customerevent'
                       when 'ConvertLab::SyncedDeal'
                         'deal'
                       else
                         'unknown'
                       end
    end
  end

  # Object that tracks the synchronization between an external object and a ConvertLab channelaccount record
  # (see {SyncedObject}) for Usage details
  class SyncedChannelAccount < SyncedObject
  end

  # Object that tracks the synchronization between an external object and a ConvertLab customer record
  # (see {SyncedObject}) for Usage details
  class SyncedCustomer < SyncedObject
  end

  # Object that tracks the synchronization between an external object and a ConvertLab customerevent record
  # (see {SyncedObject}) for Usage details
  class SyncedCustomerEvent < SyncedObject
  end

  # Object that tracks the synchronization between an external object and a ConvertLab customerevent record
  # (see {SyncedObject}) for Usage details
  class SyncedDeal < SyncedObject
  end
end
