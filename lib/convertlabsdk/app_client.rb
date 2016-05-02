# encoding: utf-8

require 'rest-client'
require 'active_record'
require 'json'
require 'date'

module ConvertLab
  # @!visibility private
  class AccessToken < ActiveRecord::Base
  end

  #
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
    #
    # @param url [String] base url of the ConvertLab API REST end points, e.g. http://api.51convert.cn
    # @param appid [String] application id. obtained from ConvertLab
    # @param secret [String] secret for the above application id
    # @param shared [Boolean] whether token will be shared. shared tokens are stored in activerecord data store
    #
    # @return [TokenStore] object created
    #
    def initialize(url, appid = 'appid', secret = 'secret', shared = false)
      self.url = url
      self.appid = appid
      self.secret = secret
      self.shared = shared
    end

    #
    # Returns a valid access token. If the token will expire within 5 seconds, a new one will be obtained and returned
    #
    # @return [String] the access token
    # @raise [AccessTokenError] when new access token cannot be obtained
    #
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

    #
    # obtain a new access token and save in database when sharing is enabled
    #
    # @return nil when successful
    # @raise [AccessTokenError] when new access token cannot be obtained
    #
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

    #
    # Returns the string representation of the token
    #
    # @return [String]
    #
    def to_s
      "token #{token} expires at #{Time.at(expires_at || 0)}"
    end

    private

    # request new access token from ConvertLab server and update the instance variable
    # TODO: add more intelligent error handling, like re-try?
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
    rescue => e
      raise AccessTokenError, "got exception #{e.class}:#{e.message}"
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

    #
    # Constructor
    #
    # @param options [Hash] options below are used. All other key/values will be passed on to RestClient::Request
    # @option options [String] :url base url of API end point
    # @option options [String] :appid application id
    # @option options [String] :secret secret for the above application id
    # @option options [Boolean] :shared_token token will be shared, defaults to false
    #
    # @return [AppClient] object created
    #
    def initialize(options = {})
      o = options.dup
      @url = o.delete(:url) || ENV['CLAB_URL'] || 'http://api.51convert.cn'
      appid = o.delete(:appid) || ENV['CLAB_APPID']
      secret = o.delete(:secret) || ENV['CLAB_SECRET']
      shared_token = o.delete(:shared_token) ? true : false
      @options = o
      @token_store = TokenStore.new(url, appid, secret, shared_token)
    end

    #
    # Returns a valid access token. If the token will expire within 5 seconds, a new one will be obtained and returned
    #
    # @return [String] the access token
    # @raise [AccessTokenError] when new access token cannot be obtained
    #
    def access_token
      @token_store.access_token
    end

    #
    # obtain a new access token and save in database when sharing is enabled
    #
    # @return nil when successful
    # @raise [AccessTokenError] when new access token cannot be obtained
    #
    def update_token
      @token_store.update_token
    end

    #
    # Returns helper object to access ConvertLab channelaccount API
    #
    # return [Resource]
    #
    def channel_account
      @channel_account ||= Resource.new(self, '/v1/channelaccounts', options)
    end

    #
    # Returns helper object to access ConvertLab custoemr API
    #
    # return [Resource]
    #
    def customer
      @customer ||= Resource.new(self, '/v1/customers', options)
    end

    #
    # Returns helper object to access ConvertLab customerevent API
    #
    # return [Resource]
    #
    def customer_event
      @customer_event ||= Resource.new(self, '/v1/customerevents', options)
    end

    #
    # Returns helper object to access ConvertLab deal API
    #
    # return [Resource]
    #
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

    #
    # @param app_client [AppClient]
    # @param resource_path [String] relative path of the resource, e.g. '/v1/customer'
    # @param options [Hash] options to past to RestClient:Request, e.g. { verify_ssl: OpenSSL::SSL::VERIFY_NONE }
    #
    # @return [Resource] object created
    #
    def initialize(app_client, resource_path, options = {})
      @app_client = app_client
      @resource_path = resource_path
      @options = options
    end

    #
    # send HTTP GET method ConvertLab API endpoint end point to retrieve a record
    #
    # @param id [#to_s] id of the ConvertLab record
    #
    # @return Hash result of JSON::parse.
    # @raise ApiError when response body contains error code or exception is thrown from RestClient
    #
    def get(id)
      parse_response { new_request(:get, id: id).execute }
    end

    #
    # send HTTP GET method to ConvertLab API end point to query for records
    #
    # @param params [Hash] Hash containing the query parameters. Parameters will be converted to URL query string.
    #
    # @return Hash result of JSON::parse.
    # @raise ApiError when response body contains error code or exception is thrown from RestClient
    #
    def find(params = {})
      parse_response { new_request(:get, params: params).execute }
    end

    #
    # send HTTP POST method to ConvertLab API end point to create new record
    #
    # @param data [Object] Any object that can be converted to JSON string with .to_json method
    #
    # @return Hash result of JSON::parse.
    # @raise ApiError when response body contains error code or exception is thrown from RestClient
    #
    def post(data)
      parse_response { new_request(:post, payload: data.to_json).execute }
    end

    #
    # send HTTP PUT method to ConvertLab API end point to update an existing record
    #
    # @param id [#to_s] id of the ConvertLab record
    # @param data [Object] Any object that can be converted to JSON string with .to_json method
    #
    # @return Hash result of JSON::parse.
    # @raise ApiError when response body contains error code or exception is thrown from RestClient
    #
    def put(id, data)
      parse_response { new_request(:put, id: id, payload: data.to_json).execute }
    end

    #
    # send HTTP DELETE method ConvertLab API endpoint end point to delete a record
    #
    # @param id [#to_s] id of the ConvertLab record
    #
    # @return nil if successful
    # @raise ApiError when response body contains error code or exception is thrown from RestClient
    #
    def delete(id)
      parse_response { new_request(:delete, id: id).execute }
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
    def parse_response(&_)
      response = yield
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
    rescue => e
      raise ApiError, "got exception #{e.class}:#{e.message}"
    end
  end
end
