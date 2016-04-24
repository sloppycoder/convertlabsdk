# encoding: utf-8
require 'rest-client'
require 'active_support'
require 'active_support/core_ext'
require 'active_record'
require 'json'
require 'date'
require 'logger'

#
# this module contains SDK to access ConvertLab API and
# helpers to facilitate synchronization local application
# objects using such APIs
#
module ConvertLab
  MAX_SYNC_ERR ||= 10
  DUMMY_TIMESTAMP ||= Time.new('2000-01-01')

  def self.logger
    @logger ||= default_logger
  end

  def self.logger=(logger)
    @logger = logger
  end

  def self.default_logger
    new_logger = Logger.new STDOUT
    new_logger.level = Logger::WARN
    new_logger
  end
  private_class_method :default_logger

  #
  # module that provides access to global logger
  #
  # @example
  #   class MyComplexClassThatNeedsLogging
  #     include ConvertLab::logging
  #
  #     def self.my_class_method
  #       logger.warn 'blah'
  #     end
  #
  #     def my_instance_method
  #       logger.debug 'blah'
  #     end
  #   end
  module Logging
    extend ActiveSupport::Concern

    # @private
    module ClassMethods
      def logger
        ConvertLab::logger
      end
    end

    # Returns the shared logger instance
    # @return [Logger]
    def logger
      ConvertLab::logger
    end
  end

  # ActiveRecord entity for storing job status
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

  # @!visibility private
  class AccessToken < ActiveRecord::Base
  end

  # Storage container for access token
  #
  # ConvertLab only allows 1 active access token per app id. When multiple processes needs to access the APIs
  # there needs to be a mechanism where each process can retrieve the shared token.
  # This class provide abstraction of access token storage. If not shared, token will be stored in an instance
  # variable. If sharing is required, the token will be stored in an activerecord backed storage.
  #
  # @api private
  class TokenStore
    include Logging

    attr_accessor :url, :appid, :secret, :shared, :token, :expires_at

    # Constructor
    # @param url [String] base url of the ConvertLab API REST end points, e.g. http://api.51convert.cn
    # @param appid [String] application id. obtained from ConvertLab
    # @param secret [String] secret for the above application id
    # @param shared [Boolean] whether token will be shared. shared tokens are stored in activerecord data store
    # @return [TokenStore] object created
    def initialize(url, appid = 'appid', secret = 'secret', shared = false)
      self.url = url
      self.appid = appid
      self.secret = secret
      self.shared = shared
    end

    # Returns a valid access token. If the token will expire within 5 seconds, a new one will be obtained and returned
    # @return [String] the access token
    # @raise [AccessTokenError] when new access token cannot be obtained
    def access_token
      read_shared_token if shared

      # we fresh 5 seconds before token expires to be safe
      if token.nil? || Time.now >= expires_at - 5
        update_token
      else
        logger.debug "return valid token #{self}"
      end

      token
    end

    # obtain a new access token and save in database when sharing is enabled
    # @return nil when successful
    # @raise [AccessTokenError] when new access token cannot be obtained
    def update_token
      # lock the token so that nobody can read it while we get a new one
      if shared
        logger.debug 'updating shared token'
        record = AccessToken.first_or_create
        record.with_lock do
          new_access_token
          record.token = token
          record.expires_at = expires_at
          record.save!
        end
      else
        new_access_token
      end
    end

    # Returns the string representation of the token
    # @return [String]
    def to_s
      "token #{token} expires at #{Time.at(expires_at || 0)}"
    end

    private

    # request new access token from ConvertLab server and update the instance variable
    def new_access_token
      headers = { accept: :json, params: { grant_type: 'client_credentials', appid: appid, secret: secret } }
      resp_body = JSON.parse(RestClient::Request.execute(method: :get, url: "#{url}/security/accesstoken",
                                                         headers: headers))
      if resp_body['error_code'].to_i != 0
        raise AccessTokenError, "get access token returned #{resp_body}"
      end

      token_expires_at = Time.now + resp_body['expires_in'].to_i
      token = resp_body['access_token']

      self.expires_at = token_expires_at
      self.token = token

      logger.debug "received new token #{self}"
    end

    # read token from a shared storage
    def read_shared_token
      # shared token needs to be read from database
      record = AccessToken.first_or_create
      self.token = record.token
      self.expires_at = record.expires_at

      logger.debug "read shared token #{self}"
    end
  end

  # Exception indicates error occurred when getting ConvertLab API access token
  class AccessTokenError < RuntimeError; end

  # Exception indicates API call to ConvertLab service has returned an error
  class ApiError < RuntimeError; end

  #
  # This provides provide entry points to access ConvertLab REST APIs
  #
  # @example
  #
  #   # create an app_client instance before doing anything
  #   app_client = ConvertLab::AppClient.new
  #
  #   # if the server has a self-signed SSL certificate
  #   app_client = ConvertLab::AppClient.new('https://api.com', 'myid', 'secret', verify_ssl: OpenSSL::SSL::VERIFY_NONE)
  #
  #   # search for customer with given mobile number
  #   app_client.customer.find(mobile: '13911223366')['records'], 1
  #
  #   # create new customer
  #   guru = { name: 'guru', mobile: mobile_no, email: 'guru@jungle.cc', external_id: 'XYZ1234' }
  #   app_client.customer.post(guru)['id']
  #
  #   # delete an existing customer record
  #   app_client.customer.delete(112233)
  #
  # @todo more examples coming soon
  class AppClient
    include Logging

    attr_accessor :url, :options

    # Constructor
    #
    # @param options [Hash] options below are used. All other key/values will be passed on to RestClient::Request
    # @option options [String] :url base url of API end point
    # @option options [String] :appid application id
    # @option options [String] :secret secret for the above application id
    # @option options [Boolean] :shared_token token will be shared, defaults to false
    #
    #
    # @return [AppClient] object created
    def initialize(options = {})
      o = options.dup
      @url = o.delete(:url) || ENV['CLAB_URL'] || 'http://api.51convert.cn'
      appid = o.delete(:appid) || ENV['CLAB_APPID']
      secret = o.delete(:secret) || ENV['CLAB_SECRET']
      shared_token = o.delete(:shared_token) ? true : false
      @options = o
      @token_store = TokenStore.new(url, appid, secret, shared_token)
    end

    # Returns a valid access token. If the token will expire within 5 seconds, a new one will be obtained and returned
    # @return [String] the access token
    # @raise [AccessTokenError] when new access token cannot be obtained
    def access_token
      @token_store.access_token
    end

    # obtain a new access token and save in database when sharing is enabled
    # @return nil when successful
    # @raise [AccessTokenError] when new access token cannot be obtained
    def update_token
      @token_store.update_token
    end

    # Returns helper object to access ConvertLab channelaccount API
    # return [Resource]
    def channel_account
      @channel_account ||= Resource.new(self, '/v1/channelaccounts', options)
    end

    # Returns helper object to access ConvertLab custoemr API
    def customer
      @customer ||= Resource.new(self, '/v1/customers', options)
    end

    # Returns helper object to access ConvertLab customerevent API
    def customer_event
      @customer_event ||= Resource.new(self, '/v1/customerevents', options)
    end

    # Returns helper object to access ConvertLab deal API
    def deal
      @deal ||= Resource.new(self, '/v1/deals', options)
    end

    private

    # test temp API. will be removed soon
    def root
      @root ||= Resource.new(self, '', options)
    end
  end

  # helper class to wrap HTTP requests to API end point
  class Resource
    include Logging
    
    attr_reader :app_client, :resource_path, :options

    # @param app_client [AppClient]
    # @param resource_path [String] relative path of the resource, e.g. '/v1/customer'
    # @param options [Hash] options to past to RestClient:Request, e.g. { verify_ssl: OpenSSL::SSL::VERIFY_NONE }
    def initialize(app_client, resource_path, options = {})
      @app_client = app_client
      @resource_path = resource_path
      @options = options
    end

    # send HTTP GET method ConvertLab API endpoint end point to retrieve a record
    # @param id [#to_s] id of the ConvertLab record
    # @return Hash result of JSON::parse.
    # @raise ApiError when response body contains error code
    # @raise Exception any exception from RestClient
    def get(id)
      parse_response new_request(:get, id: id).execute
    end

    # send HTTP GET method to ConvertLab API end point to query for records
    # @param params [Hash] Hash containing the query parameters. Parameters will be converted to URL query string.
    # @return Hash result of JSON::parse.
    # @raise ApiError when response body contains error code
    # @raise Exception any exception from RestClient
    def find(params = {})
      parse_response new_request(:get, params: params).execute
    end

    # send HTTP POST method to ConvertLab API end point to create new record
    # @param data [Object] Any object that can be converted to JSON string with .to_json method
    # @return Hash result of JSON::parse.
    # @raise ApiError when response body contains error code
    # @raise Exception any exception from RestClient
    def post(data)
      parse_response new_request(:post, payload: data.to_json).execute
    end

    # send HTTP PUT method to ConvertLab API end point to update an existing record
    # @param id [#to_s] id of the ConvertLab record
    # @param data [Object] Any object that can be converted to JSON string with .to_json method
    # @return Hash result of JSON::parse.
    # @raise ApiError when response body contains error code
    # @raise Exception any exception from RestClient
    def put(id, data)
      parse_response new_request(:put, id: id, payload: data.to_json).execute
    end

    # send HTTP DELETE method ConvertLab API endpoint end point to delete a record
    # @param id [#to_s] id of the ConvertLab record
    # @return nil if successful
    # @raise ApiError when response body contains error code
    # @raise Exception any exception from RestClient
    def delete(id)
      parse_response new_request(:delete, id: id).execute
    end

    private

    # Construct a new RestClient::Request object using parameters. Access token will be added to URL.
    # SSL parameters, if any, will be applied too
    def new_request(*args)
      opts = args.extract_options!
      method = args.first
      params = opts[:params] || {}
      h = { accept: :json, params: params.merge(access_token: app_client.access_token) }
      h[:content_type] = :json if [:put, :post].include?(method)
      RestClient::Request.new options.merge(method: method, headers: h, 
                                            url: resource_url(opts[:id]), payload: opts[:payload])
    end

    # Construct REST endpoint URL
    def resource_url(id = nil)
      url = app_client.url + resource_path 
      url += "/#{id}" if id
      url
    end      
  
    # parse the response for error information
    # raise the error is error code is not 0, otherwise return the 
    # object parsed from response json
    def parse_response(response)
      case response.code
      when 204 # No Content
        nil
      when 200..201
        resp_obj = JSON.parse(response)
        if resp_obj.is_a?(Hash) && resp_obj.key?('error_code') 
          err_code = resp_obj['error_code'].to_i
          if err_code != 0
            raise ApiError, "#{err_code} - #{resp_obj['error_description']}"
          end
        end
        resp_obj
      end
    end
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
