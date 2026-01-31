# frozen_string_literal: true

require 'appom/version'
require 'appium_lib'
require 'appom/exceptions'
require 'appom/logging'
require 'appom/element_validation'
require 'appom/retry'
require 'appom/wait'
require 'appom/smart_wait'
require 'appom/element_cache'
require 'appom/screenshot'
require 'appom/configuration'

# The main Appom module provides a comprehensive Page Object Model framework for Appium.
#
# Appom gives you a simple, clean and semantic DSL for describing mobile applications.
# It implements the Page Object Model pattern on top of Appium with enhanced error
# handling, logging, performance monitoring, visual testing, and element state tracking.
#
# @example Basic usage
#   # Register Appium driver
#   Appom.register_driver do
#     Appium::Driver.new(options, false)
#   end
#
#   # Configure global settings
#   Appom.configure do |config|
#     config.max_wait_time = 30
#   end
#
#   # Define page objects with enhanced features
#   class LoginPage < Appom::Page
#     element :email, :id, 'email_field'
#     element :password, :id, 'password_field'
#     element :submit, :accessibility_id, 'submit_button'
#
#     def login_with_monitoring(email, password)
#       Appom::Performance.time_operation('login_process') do
#         self.email.set email
#         self.password.set password
#         self.submit.click
#       end
#     end
#   end
#
# @example Visual testing
#   # Perform visual regression test
#   Appom::Visual.regression_test('login_screen')
#
# @example Performance monitoring
#   # Get performance statistics
#   stats = Appom::Performance.summary
#   puts "Average operation time: #{stats[:average_operation_time]}s"
#
# @see https://github.com/hoangtaiki/appom
# @author Harry.Tran
module Appom
  include Appom::Logging
  extend Appom::Logging

  autoload :ElementContainer, 'appom/element_container'
  autoload :Page, 'appom/page'
  autoload :Wait, 'appom/wait'
  autoload :Section, 'appom/section'
  autoload :ElementFinder, 'appom/element_finder'
  autoload :Helpers, 'appom/helpers'
  autoload :Retry, 'appom/retry'
  autoload :SmartWait, 'appom/smart_wait'
  autoload :ElementCache, 'appom/element_cache'
  autoload :Screenshot, 'appom/screenshot'
  autoload :Configuration, 'appom/configuration'
  autoload :Performance, 'appom/performance'
  autoload :ElementState, 'appom/element_state'
  autoload :Visual, 'appom/visual'

  class << self
    attr_accessor :driver, :max_wait_time

    # Configure appom global settings
    #
    # @yieldparam [self] config The Appom module for configuration
    # @example Configure wait time
    #   Appom.configure do |config|
    #     config.max_wait_time = 30
    #   end
    def configure
      yield self
    end

    # Register a new Appium driver for Appom
    #
    # @yield [] Block that returns an Appium::Driver instance
    # @return [Appium::Driver] The registered driver instance
    # @raise [DriverError] If driver registration fails
    #
    # @example Register iOS driver
    #   Appom.register_driver do
    #     options = {
    #       appium_lib: { server_url: 'http://localhost:4723' },
    #       caps: { platformName: 'iOS', deviceName: 'iPhone 13' }
    #     }
    #     Appium::Driver.new(options, false)
    #   end
    def register_driver(&)
      log_info('Registering Appium driver')

      # Register driver with performance monitoring
      @driver = Performance.time_operation('driver_registration', &)

      setup_exit_handler

      # Initialize element state tracking if enabled
      if Configuration.get('element_state.tracking_enabled', false)
        ElementState.tracker
        log_info('Element state tracking initialized')
      end

      log_info('Appium driver registered successfully')
      @driver
    rescue StandardError => e
      log_error('Failed to register driver', { error: e.message })
      raise DriverError, "Failed to register driver: #{e.message}"
    end

    # Start the registered Appium driver
    #
    # @raise [DriverNotInitializedError] If no driver has been registered
    # @raise [DriverOperationError] If driver start fails
    def start_driver
      raise DriverNotInitializedError unless @driver

      log_info('Starting Appium driver')

      # Start driver with performance monitoring
      Performance.time_operation('driver_start') do
        @driver.start_driver
      end

      log_info('Appium driver started successfully')
    rescue DriverNotInitializedError
      raise
    rescue StandardError => e
      log_error('Failed to start driver', { error: e.message })
      raise DriverOperationError.new('start_driver', e.message)
    end

    # Reset the device, relaunching the application
    #
    # @raise [DriverNotInitializedError] If no driver has been registered
    # @raise [DriverOperationError] If driver reset fails
    def reset_driver
      raise DriverNotInitializedError unless @driver

      log_info('Resetting Appium driver')

      # Reset driver with performance monitoring
      Performance.time_operation('driver_reset') do
        @driver.reset
      end

      log_info('Appium driver reset successfully')
    rescue DriverNotInitializedError
      raise
    rescue StandardError => e
      log_error('Failed to reset driver', { error: e.message })
      raise DriverOperationError.new('reset', e.message)
    end

    # After run all scenario and exit we will quit driver to close application under test
    def setup_exit_handler
      main = Process.pid
      at_exit do
        cleanup_on_exit(main)
      end
    end

    private

    # Extracted method to enable testing
    def cleanup_on_exit(main_pid)
      return unless Process.pid == main_pid

      begin
        # Export performance metrics before quitting
        if defined?(Performance) && Performance.monitor.metrics.any?
          Performance.export_metrics(format: :json)
          log_info('Performance metrics exported on exit')
        end

        @driver&.driver_quit
      rescue StandardError => e
        # Log error but don't raise during exit
        warn "Warning: Failed to quit driver during exit: #{e.message}"
      end
    end

    public

    # Performance monitoring convenience methods
    def performance_stats
      Performance.summary
    end

    def export_performance_metrics(**)
      Performance.export_metrics(**)
    end

    # Visual testing convenience methods
    def visual_regression_test(name, **)
      Visual.regression_test(name, **)
    end

    def generate_visual_report(**)
      Visual.generate_report(**)
    end

    # Element state tracking convenience methods
    def element_tracking_summary
      ElementState.tracking_summary
    end

    def export_element_tracking(**)
      ElementState.export_data(**)
    end
  end

  @max_wait_time = 20
end
