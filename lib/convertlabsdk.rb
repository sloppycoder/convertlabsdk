# encoding: utf-8
#
# this module contains SDK to access ConvertLab API and
# helpers to facilitate synchronization local applicaiton
# objects using such APIs
#
#
require 'rest-client'
require 'active_support'
require 'active_support/core_ext'
require 'active_record'
require 'json'
require 'date'
require 'logger'

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

  # include this module will give a class logger class method and instance method
  module Logging
    extend ActiveSupport::Concern

    module ClassMethods
      def logger
        ConvertLab::logger
      end
    end

    def logger
      ConvertLab::logger
    end
  end

  class JobStatus < ActiveRecord::Base
    def new?
      last_sync == DUMMY_TIMESTAMP
    end
  end

  def self.job_status(job_name)
    job = JobStatus.where(name: job_name).first_or_create
    job.last_sync ||= DUMMY_TIMESTAMP
    job
  end

  class AccessToken < ActiveRecord::Base
  end

  # store the access token
  class TokenStore
    include Logging

    attr_accessor :url, :appid, :secret, :shared, :token, :expires_at

    def initialize(url, appid = 'appid', secret = 'secret', shared = false)
      self.url = url
      self.appid = appid
      self.secret = secret
      self.shared = shared
    end

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

    def update_token
      # lock the token so that nobody can read it while we get a new one
      if shared
        logger.info 'updating shared token'
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

    private

    def to_s
      "token #{token} expires at #{Time.at(expires_at || 0)}"
    end

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

    def read_shared_token
      # shared token needs to be read from database
      record = AccessToken.first_or_create
      self.token = record.token
      self.expires_at = record.expires_at

      logger.debug "read shared token #{self}"
    end

  end

  class AccessTokenError < RuntimeError; end
  class ApiError < RuntimeError; end

  #
  # used to access APIs
  #
  class AppClient
    include Logging

    attr_accessor :url, :options, :token_store

    def initialize(options = {})
      o = options.dup
      @url = o.delete(:url) || ENV['CLAB_URL'] || 'http://api.51convert.cn'
      appid = o.delete(:appid) || ENV['CLAB_APPID']
      secret = o.delete(:secret) || ENV['CLAB_SECRET']
      shared_token = o.delete(:shared_token) ? true : false
      @options = o
      @token_store = TokenStore.new(url, appid, secret, shared_token)
    end

    def access_token
      @token_store.access_token
    end

    def channel_account
      @channel_account ||= Resource.new(self, '/v1/channelaccounts', options)
    end

    def customer
      @customer ||= Resource.new(self, '/v1/customers', options)
    end

    def customer_event
      @customer_event ||= Resource.new(self, '/v1/customerevents', options)
    end

    def deal
      @deal ||= Resource.new(self, '/v1/deals', options)
    end

    # for testing only...
    def root
      @root ||= Resource.new(self, '', options)
    end
  end

  # helper class to wrap HTTP requests to API end point
  class Resource
    include Logging
    
    attr_reader :app_client, :resource_path, :options

    def initialize(app_client, resource_path, options = {})
      @app_client = app_client
      @resource_path = resource_path
      @options = options
    end

    def get(id)
      parse_response new_request(:get, id: id).execute
    end

    def find(params = {})
      parse_response new_request(:get, params: params).execute
    end

    def post(data)
      parse_response new_request(:post, payload: data.to_json).execute
    end

    def put(id, data)
      parse_response new_request(:put, id: id, payload: data.to_json).execute
    end

    def delete(id)
      parse_response new_request(:delete, id: id).execute
    end

    private

    # def new_request(method = :get, id: nil, params: {}, payload: {})
    def new_request(*args)
      opts = args.extract_options!
      method = args.first
      params = opts[:params] || {}
      h = { accept: :json, params: params.merge(access_token: app_client.access_token) }
      h[:content_type] = :json if [:put, :post].include?(method)
      RestClient::Request.new options.merge(method: method, headers: h, 
                                            url: resource_url(opts[:id]), payload: opts[:payload])
    end

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

  class SyncError < RuntimeError; end

  #
  # class that facilitate syncing of external objects to convertlab 
  # cloud services locally maintain external object and cloud object mappings
  # it mains a local datastore that stores the mapping:
  # 
  class SyncedObject < ActiveRecord::Base
    include Logging

    validates :ext_channel, :ext_type, :ext_id, presence: true
    enum sync_type: { SYNC_UP: 0, SYNC_DOWN: 1, SYNC_BOTHWAYS: 2 }  
    
    before_save :default_values
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

    # no idea why it complains about this method
    # rubocop:disable Metrics/CyclomaticComplexity:
    # rubocop:disable Metrics/PerceivedComplexity:
    def need_sync?
      if is_ignored || err_count >= MAX_SYNC_ERR
        false
      elsif last_sync == DUMMY_TIMESTAMP
        true
      else
        case sync_type.to_sym
        when :SYNC_UP
          # clab_id is nil indicates no syncing was ever done
          # we'll need to sync regardless of last_sync
          # this could happen when clab object was deleted after
          # the last sync
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

    def sync_success(timestamp = Time.now)
      logger.debug "#{self} sync success"
      self.last_sync = timestamp
      save!
    end

    def sync_failed(timestamp = Time.now, msg = '')
      logger.warn "#{self} sync failed with error #{msg}"
      self.last_err = timestamp
      self.err_msg = msg
      self.err_count += 1
      save!
    end

    def link_ext_obj(channel, type, id)
      self.ext_channel = channel
      self.ext_type = type
      self.ext_id = id
    end

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

    def unlock
      self.is_locked = false
      self.locked_at = nil
      save!
    end

    # used in loggin
    def ext_obj
      "ext(#{ext_channel}, #{ext_type}, #{ext_id})"
    end

    def clab_obj
      id_string = clab_id ? clab_id : 'new'
      "clab(#{clab_type}, #{id_string})"
    end

    def to_s
      t = (type || 'unknown').split(':')[-1]
      i = id ? id.to_s : 'new'
      "#{t}(#{i})"
    end
  end

  class SyncedChannelAccount < SyncedObject
  end

  class SyncedCustomer < SyncedObject
  end

  class SyncedCustomerEvent < SyncedObject
  end
end
