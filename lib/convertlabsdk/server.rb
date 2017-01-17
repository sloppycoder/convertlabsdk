# encoding: utf-8

require 'sinatra/base'
require 'erb'
require 'convertlabsdk'

defined?(Encoding) || Encoding.default_external = Encoding::UTF_8

module ConvertLab
  class Server < Sinatra::Base
    dir = File.dirname(File.expand_path(__FILE__))
    @url_prefix = ''

    set :views, "#{dir}/server/views"

    if respond_to? :public_folder
      set :public_folder, "#{dir}/server/public"
    else
      set :public, "#{dir}/server/public"
    end

    set :static, true

    helpers do
      include Rack::Utils

      def current_page
        url_path request.path_info.sub('/', '')
      end

      def url_path(*path_parts)
        [url_prefix, path_prefix, path_parts].join('/').squeeze('/')
      end
      alias_method :u, :url_path

      def redirect_url_path(*path_parts)
        [path_prefix, path_parts].join('/').squeeze('/')
      end

      def path_prefix
        request.env['SCRIPT_NAME']
      end

      def class_if_current(path = '')
        'class="current"' if current_page[0, path.size] == path
      end

      def tab(name)
        dname = name.to_s.downcase.sub(' ', '')
        path = url_path(dname)
        "<li #{class_if_current(path)}><a href='#{path}'>#{name}</a></li>"
      end

      def tabs
        ConvertLab::Server.tabs
      end

      def url_prefix
        ConvertLab::Server.url_prefix
      end
    end

    def show(page, layout = true)
      response['Cache-Control'] = 'max-age=0, private, must-revalidate'
      begin
        erb page.to_sym, layout: layout
      rescue => e
        erb :error, { layout: false }, error: e
      end
    end


    # to make things easier on ourselves
    get '/?' do
      redirect redirect_url_path(:datasource)
    end

    get '/datasource/?' do
      show :datasource
    end

    get '/syncedobjects/?' do
      show :synced_objects
    end

    get '/resque' do
      redirect "#{url_prefix}/../resque"
    end

    def self.tabs
      @tabs ||= ['Synced Objects', 'Data Source'] + (defined?(::Resque::Server) ? ['Resque'] : [])
    end

    attr_writer :url_prefix

    def self.url_prefix
      (@url_prefix.nil? || @url_prefix.empty?) ? '' : @url_prefix + '/'
    end
  end
end
