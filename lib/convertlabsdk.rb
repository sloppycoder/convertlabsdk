# encoding: utf-8
#
# this module contains SDK to access ConvertLab API and 
# helpers to facilitate syncrhonization local applicaiton
# objects using such APIs
#
#
require 'rest-client'
require 'json'
require 'active_record'

module ConvertLab
  
  MAX_SYNC_ERR ||= 10
  DUMMY_TIMESTAMP ||= Time.at(0)

  class AccessTokenError < RuntimeError; end
  class ApiError < RuntimeError; end

  #
  # used to access APIs
  #
  class AppClient
    
    attr_accessor :url, :appid, :secret

    def initialize(url, appid, secret)
      @url = url
      @appid = appid
      @secret = secret
      @token = nil
    end
      
    def access_token
      # we fresh 5 seconds before token expires to be safe
      if @token && Time.now.to_i < @token_expires_at - 5
        @token
      else
        new_access_token
      end
    end

    def new_access_token
      resp_body = JSON.parse RestClient.get("#{url}/security/accesstoken", 
                                            params: { grant_type: 'client_credentials', 
                                                      appid: appid, secret: secret })
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
      @channel_account ||= Resource.new(self, '/v1/channelaccounts')
    end

    def customer
      @customer ||= Resource.new(self, '/v1/customers')
    end

    def customer_event
      @customer_event ||= Resource.new(self, '/v1/customerevents')
    end
  end

  # helper class to wrap HTTP requests to API end point
  class Resource
    
    attr_reader :app_client, :resource_path

    def initialize(app_client, resource_path)
      @app_client = app_client
      @resource_path = resource_path
    end

    def get(id = nil)
      parse_response RestClient.get(resource_url(id), 
                                    params: { access_token: app_client.access_token }, 
                                    accept: :json)
    end

    def find(params = {})
      parse_response RestClient.get(resource_url, 
                                    params: params.merge(access_token: app_client.access_token),
                                    accept: :json)
    end

    def post(data)
      parse_response RestClient.post(resource_url, data.to_json, 
                                     params: { access_token: app_client.access_token }, 
                                     accept: :json, content_type: :json)
    end

    def put(id, data)
      parse_response RestClient.put(resource_url(id), data.to_json, 
                                    params: { access_token: app_client.access_token }, 
                                    accept: :json, content_type: :json)
    end

    def delete(id)
      parse_response RestClient.delete(resource_url(id), 
                                       params: { access_token: app_client.access_token },
                                       accept: :json)
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
  # the APIs provide support for the following use case scenarios:
  #
  # TODO: to do need to use with_lock for concurrency?
  # 
  class SyncedObject < ActiveRecord::Base
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
                       else
                         'unknown'
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
          clab_id == nil || ext_last_update > last_sync
        when :SYNC_DOWN
          clab_last_update > last_sync
        else
          raise SyncError, 'sync mode not supported'
        end
      end
    end

    def sync_success(timestamp = Time.now)
      self.last_sync = timestamp
      save!
    end

    def sync_failed(timestamp = Time.now, msg = '')
      self.last_err = timestamp
      self.err_msg = msg
      self.err_count += 1
      save!
    end

    def link_ext_obj(channel, type, id, timestamp = DUMMY_TIMESTAMP)
      self.ext_channel = channel
      self.ext_type = type
      self.ext_id = id
      self.ext_last_update = timestamp
    end

    def link_obj(id, timestamp = DUMMY_TIMESTAMP)
      self.clab_id = id
      self.clab_last_update = timestamp
    end
  end

  class SyncedChannelAccount < SyncedObject
  end

  class SyncedCustomer < SyncedObject
  end

  class SyncedCustomerEvent < SyncedObject
  end
end
