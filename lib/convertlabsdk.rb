# encoding: utf-8
#
# this module contains SDK to access ConvertLab API and 
# helpers to facilitate syncrhonization local applicaiton
# objects using such APIs
#
#
require 'rest-client'
require 'json'
require 'active_support/all'
require 'active_record'
require 'date'
require 'logger'

module ConvertLab
  
  mattr_accessor :logger

  MAX_SYNC_ERR ||= 10
  DUMMY_TIMESTAMP ||= Time.at(0)

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

  class AccessTokenError < RuntimeError; end
  class ApiError < RuntimeError; end

  #
  # used to access APIs
  #
  class AppClient
    include Logging

    attr_accessor :url, :appid, :secret, :options

    def initialize(url, appid, secret, options = {})
      @url = url
      @appid = appid
      @secret = secret
      @options = options
      @token = nil
    end
      
    def access_token
      # we fresh 5 seconds before token expires to be safe
      if @token && Time.now.to_i < @token_expires_at - 5
        @token
      else
        access_token!
      end
    end

    def access_token!
      o = options.merge(params: { grant_type: 'client_credentials', appid: appid, secret: secret })
      resp_body = JSON.parse RestClient.get("#{url}/security/accesstoken", o)
                                            
      if resp_body['error_code'].to_i != 0 
        raise AccessTokenError, "get access token returned #{resp_body}" 
      end

      @token_expires_at = Time.now.to_i + resp_body['expires_in'].to_i  
      @token = resp_body['access_token']
      @token
    end

    def expire_token!
      @token_expires_at = Time.now.to_i - 1
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
  end

  # helper class to wrap HTTP requests to API end point
  class Resource
    include Logging
    
    ACCEPT = { accept: :json }.freeze
    CONTENT_TYPE = { content_type: :json }.freeze

    attr_reader :app_client, :resource_path, :options

    def initialize(app_client, resource_path, options = {})
      @app_client = app_client
      @resource_path = resource_path
      @options = options
    end

    def token
      { access_token: app_client.access_token }
    end

    def get(id = nil)
      opt = options.merge(params: token).merge(ACCEPT)
      parse_response RestClient.get(resource_url(id), opt)
    end

    def find(params = {})
      opt = options.merge(params: token.merge(params)).merge(ACCEPT)
      parse_response RestClient.get(resource_url, opt)
    end

    def post(data)
      opt = options.merge(params: token).merge(ACCEPT).merge(CONTENT_TYPE)
      parse_response RestClient.post(resource_url, data.to_json, opt)
    end

    def put(id, data)
      opt = options.merge(params: token).merge(ACCEPT).merge(CONTENT_TYPE)
      parse_response RestClient.put(resource_url(id), data.to_json, opt)
    end

    def delete(id)
      opt = options.merge(params: token).merge(ACCEPT)
      parse_response RestClient.delete(resource_url(id), opt)
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
            raise ApiError "#{err_code} - #{resp_obj['error_description']}"
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
      clab_id = filters.delete(:clab_id)
      f = filters.dup
      f.merge(sync_type: sync_types[:SYNC_UP]) unless filters.key? :sync_type
      sync_obj = where(f).first_or_create
      logger.info "#{sync_obj} #{sync_obj.ext_obj} <-> #{sync_obj.clab_obj}"
      sync_obj.sync api_client, data, clab_id
    end

    def sync(api_client, data, new_clab_id)
      link_clab_obj new_clab_id
      self.ext_last_update = Time.new(data['last_update'])
      save!
      
      if need_sync?
        do_sync_up api_client, data
      else
        logger.info "#{self} is up to date with #{clab_obj}"
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
      self.clab_last_update = DateTime.iso8601(obj['lastUpdated']).to_time
      sync_success
      logger.info "#{self} marking sync sync success"
    rescue RuntimeError => e
      sync_fail e.to_s
      logger.error "#{self} sync error. err_count => #{err_count}, error => #{e}"
    end

    def need_sync?
      if is_ignored || err_count >= MAX_SYNC_ERR
        false
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

    def sync_success(timestamp = Time.now)
      logger.debug "#{self} sync success"
      self.last_sync = timestamp
      save!
    end

    def sync_failed(timestamp = Time.now, msg = '')
      logger.debug "#{self} sync failed with error #{msg}"
      self.last_err = timestamp
      self.err_msg = msg
      self.err_count += 1
      save!
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

    def link_ext_obj(channel, type, id)
      self.ext_channel = channel
      self.ext_type = type
      self.ext_id = id
    end

    def link_clab_obj(new_clab_id)
      old_clab_id = clab_id
      if old_clab_id != new_clab_id
        self.clab_id = new_clab_id
        unless old_clab_id.nil?
          logger.warn "#{self} overwriting #{old_clab_id} with #{clab_obj}"
        end
      end
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
