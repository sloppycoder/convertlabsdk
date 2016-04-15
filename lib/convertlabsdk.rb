# encoding: utf-8
#
# this module contains SDK to access ConvertLab API and 
# helpers to facilitate syncrhonization local applicaiton
# objects using such APIs
#
#
require 'rest-client'
require 'json'

# uncomment the line below to see request/resposne
# RestClient.log = 'stdout'

module ConvertLab
  
  class AccessTokenError < RuntimeError; end
  class ApiError < RuntimeError; end

  #
  # used to access APIs
  #
  class AppClient
    
    attr_reader :url, :options
    attr_accessor :appid, :secret

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

    def parse_response(response)
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

  #
  # helpers that facilitate syncing of external objects to convertlab 
  # cloud services locally maintain external object and cloud object mappings
  # it mains a local datastore that stores the mapping:
  #  
  #  clab object type and id
  #  external object type and id
  #  last update of local object attributes
  #  last upload to clab
  #  last download from clab (to be sync back to external app)??
  #
  class SycnedObject
  end
end
