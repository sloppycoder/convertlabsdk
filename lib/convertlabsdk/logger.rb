# encoding: utf-8

require 'logger'
require 'active_support'

module ConvertLab
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
  private_class_method :default_logger

  #
  # module that provides access to global logger
  #
  # @example
  #   class MyComplexClassThatNeedsLogging
  #     include ConvertLab::logging
  #
  #     def self.my_class_method
  #       logger.warn 'blah'
  #     end
  #
  #     def my_instance_method
  #       logger.debug 'blah'
  #     end
  #   end
  module Logging
    extend ActiveSupport::Concern

    # @private
    module ClassMethods
      def logger
        ConvertLab::logger
      end
    end

    # Returns the shared logger instance
    # @return [Logger]
    def logger
      ConvertLab::logger
    end
  end
end
