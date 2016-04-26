# encoding: utf-8

require 'convertlabsdk'

module Synchronizer
  TEST_CHANNEL = 'TEST_CHANNEL'
  
  class OrderReader

    @queue = :order

    def self.perform(*args)
      puts "*** OrderReader *** "
      intervals.each do |since|
        order_details(since).each do |order|
          clab_cust = Synchronizer.app_client.customer.find(mobile: order['mobile'])['rows'].first || {}
          customer = extract_customer_info_from_order(order)
          ext_id = order['membershipNo']
          filter = { ext_channel: TEST_CHANNEL, ext_type: 'buyer', ext_id: ext_id, clab_id: clab_cust['id'] }
          Resque.enqueue(CustomerUploader, customer, filter)
        end
      end
      sleep Random.rand(5.0)
      puts "*** OrderReader done *** "
    end

    def self.extract_customer_info_from_order(order)
      # dummy for now fix later.
      order.dup
    end

    def self.testdata
      @data ||= load_testdata
    end

    def self.load_testdata
      require 'csv'
      t = []
      CSV.parse(IO.read(Synchronizer.config['app']['data']), skip_blanks: true, headers: true) do |row|
        t << row.to_hash
      end
      t
    end

    def self.intervals
      testdata.collect { |row| row['last_update'] }.uniq.sort
    end

    def self.order_details(day)
      testdata.select { |r| r['last_update'] == day }
    end
  end

  class CustomerUploader
    @queue = :customer

    def self.perform(*args)
      opts = args.extract_options!
      customer = args
      puts "*** CustomerUploader #{opts} ***"
      ConvertLab::SyncedCustomer.sync(SyncCustomer::app_client.customer, customer, opts)
      sleep Random.rand(5.0)
      puts "*** CustomerUploader done ***"
    end
  end

  def self.app_client
    @app_client ||= new_app_client
  end

  def self.new_app_client
    url = config['app']['url'] || 'http://api.51convert.cn'
    ConvertLab::AppClient.new(url: url, appid: ENV['CLAB_APPID'], secret: ENV['CLAB_SECRET'])
  end
  private_class_method :new_app_client

  def self.config(config_file=nil)
    @config ||= load_config(config_file)
  end

  def self.load_config(config_file)
    require 'yaml'

    e = ENV['RAILS_ENV'] || 'development'
    e += '_jruby' if RUBY_PLATFORM == 'java'
    YAML::load_file(config_file)[e]
  end
  private_class_method :load_config
end
