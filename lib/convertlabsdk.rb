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

  #
  # used to access APIs
  #
  class AppClient
    attr_reader :url, :options

    def initialize(url, options = {})
      @url = url
      @options = options
      @token = nil
    end
      
    def appid
      @options[:appid]
    end

    def secret
      @options[:secret]
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
      response = RestClient.get "#{url}/security/accesstoken", 
                                params: @options.merge(grant_type: 'client_credentials')
      resp_body = JSON.parse response.body                                
      if resp_body['error_code'].to_i != 0 
        raise AccessTokenError, "get access token returned #{response}" 
      end

      @token_expires_at = Time.now.to_i + resp_body['expires_in'].to_i  
      @token = resp_body['access_token']
      @token
    end

    def expire_token!
      @token_expires_at = Time.now.to_i - 1
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
