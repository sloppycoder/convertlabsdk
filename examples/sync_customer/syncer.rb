# encoding: utf-8

require 'convertlabsdk'
require_relative 'testdata'

module Synchronizer
  TEST_CHANNEL = 'TEST_CHANNEL'

  class OrderReader
    include ConvertLab::Logging

    @queue = :order

    def self.perform(*args)
      puts "*** OrderReader #{args} ***"
      opts = args.extract_options!
      TestData.intervals.each do |since|
        TestData.order_details(since).each do |order|
          clab_cust = Synchronizer.app_client.customer.find(mobile: order['mobile'])['rows'].first || {}
          customer = extract_customer_info_from_order(order)
          ext_id = order['membershipNo']
          filter = { ext_channel: TEST_CHANNEL, ext_type: 'buyer', ext_id: ext_id, clab_id: clab_cust['id'].to_i }

          if opts[:use_queue] || opts['use_resque']
            require 'resque'
            Resque.enqueue(CustomerUploader, customer, filter)
          else
            CustomerUploader.perform(customer, filter)
          end
        end
        sleep Random.rand(5.0)
        puts '*** OrderReader done ***'
      end
    end

    def self.extract_customer_info_from_order(order)
      # dummy for now fix later.
      order.dup
    end
  end

  class CustomerUploader
    include ConvertLab::Logging

    @queue = :customer

    def self.perform(*args)
      opts = args.extract_options!
      customer = args.first
      puts "*** CustomerUploader #{opts} ***"
      ConvertLab::SyncedCustomer.sync(Synchronizer.app_client.customer, customer, opts)
      sleep Random.rand(5.0)
      puts '*** CustomerUploader done ***'
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
    #ActiveRecord::Base.logger = logger

    @log_init = true
  end

  # entry point for running in standalone mode
  # it is not called when running under Resque
  def self.run
    env = ENV['RAILS_ENV'] || 'development'
    db_config = YAML::load(File.open('config/database.yml'))[env]
    ActiveRecord::Base.establish_connection(db_config)
    ActiveRecord::Migrator.migrate('db/migrate/')

    init_logging

    while true
      Synchronizer::OrderReader.perform(use_queue: false)
      sleep Random.rand(5.0)
    end
  end
end

if __FILE__ == $0
  Synchronizer.run
end

