# encoding: utf-8

require 'resque'
require 'convertlabsdk'
require_relative 'testdata'

module Synchronizer
  TEST_CHANNEL = 'TEST_CHANNEL'
  
  class OrderReader
    include ConvertLab::Logging

    @queue = :order

    def self.perform(*args)
      logger.info '*** OrderReader ***'
      TestData.intervals.each do |since|
        TestData.order_details(since).each do |order|
          clab_cust = Synchronizer.app_client.customer.find(mobile: order['mobile'])['rows'].first || {}
          customer = extract_customer_info_from_order(order)
          ext_id = order['membershipNo']
          filter = { ext_channel: TEST_CHANNEL, ext_type: 'buyer', ext_id: ext_id, clab_id: clab_cust['id'] }
          Resque.enqueue(CustomerUploader, customer, filter)
        end
      end
      sleep Random.rand(5.0)
      logger.info '*** OrderReader done ***'
    end

    def self.extract_customer_info_from_order(order)
      # dummy for now fix later.
      order.dup
    end

  end

  class CustomerUploader
    @queue = :customer

    def self.perform(*args)
      opts = args.extract_options!
      customer = args
      logger.info "*** CustomerUploader #{opts} ***"
      ConvertLab::SyncedCustomer.sync(SyncCustomer::app_client.customer, customer, opts)
      sleep Random.rand(5.0)
      logger.info '*** CustomerUploader done ***'
    end
  end

  def self.app_client
    @app_client ||= new_app_client
  end

  def self.new_app_client
    ConvertLab::AppClient.new(shared_token: true)
  end

  def self.init_logging

    return if @log_init

    env = ENV['CLAB_LOGGER'] || 'stdout'
    if env.upcase == 'STDOUT'
      puts " Logging to STDOUT "
      logger = Logger.new STDOUT
    else
      puts " Logging to #{env} "
      log_f = File.open(env, File::WRONLY | File::APPEND | File::CREAT)
      logger = Logger.new log_f
    end
    logger.level = Logger::DEBUG

    ConvertLab.logger = logger
    Resque.logger = logger
    ActiveRecord::Base.logger = logger

    @log_init = true
  end
end
