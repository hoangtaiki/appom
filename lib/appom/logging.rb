# frozen_string_literal: true

require 'logger'

# Main module for Appom automation framework
module Appom
  # Logging functionality for Appom automation framework
  # Provides centralized logging with configurable levels and formatters
  module Logging
    class << self
      attr_writer :logger

      def logger
        @logger ||= create_default_logger
      end

      def level=(level)
        logger.level = level
      end

      def level
        logger.level
      end

      private

      def create_default_logger
        logger = Logger.new($stdout)
        logger.level = Logger::INFO
        logger.formatter = proc do |severity, datetime, _progname, msg|
          # Handle datetime parameter which can be Time object or integer timestamp
          time = datetime.is_a?(Time) ? datetime : Time.at(datetime)
          "[#{time.strftime('%Y-%m-%d %H:%M:%S')}] #{severity.ljust(5)} [Appom] #{msg}\n"
        end
        logger
      end
    end

    # Instance methods for including in classes
    def logger
      Logging.logger
    end

    def log_debug(message, context = {})
      logger.debug(format_message(message, context))
    end

    def log_info(message, context = {})
      logger.info(format_message(message, context))
    end

    def log_warn(message, context = {})
      logger.warn(format_message(message, context))
    end

    def log_error(message, context = {})
      logger.error(format_message(message, context))
    end

    def log_element_action(action, element_info, duration = nil)
      message = "#{action.upcase}: #{element_info}"
      message += " (#{duration}ms)" if duration
      log_info(message)
    end

    def log_wait_start(condition, timeout)
      log_debug("WAIT: Starting wait for '#{condition}' (timeout: #{timeout}s)")
    end

    def log_wait_end(condition, duration, success = true)
      status = success ? 'SUCCESS' : 'TIMEOUT'
      log_debug("WAIT: #{status} for '#{condition}' (#{duration}s)")
    end

    private

    def format_message(message, context)
      return message if context.empty?

      context_str = context.map { |k, v| "#{k}=#{v}" }.join(' ')
      "#{message} | #{context_str}"
    end
  end

  # Configure logging
  def self.configure_logging(level: :info, output: nil, custom_logger: nil)
    if custom_logger
      Logging.logger = custom_logger
    else
      logger = Logger.new(output || $stdout)
      logger.level = case level.to_s.downcase
                     when 'debug' then Logger::DEBUG
                     when 'info' then Logger::INFO
                     when 'warn' then Logger::WARN
                     when 'error' then Logger::ERROR
                     when 'fatal' then Logger::FATAL
                     else Logger::INFO
                     end
      logger.formatter = proc do |severity, datetime, _progname, msg|
        # Handle the case where datetime might be mocked as an integer in tests
        timestamp = datetime.respond_to?(:strftime) ? datetime.strftime('%Y-%m-%d %H:%M:%S') : datetime.to_s
        "[#{timestamp}] #{severity.ljust(5)} [Appom] #{msg}\n"
      end
      Logging.logger = logger
    end
  end
end
