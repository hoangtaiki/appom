# frozen_string_literal: true

require 'appom/version'
require 'appium_lib'
require 'appom/cucumber'

module Appom
  # A item was defined without a selector.
  class InvalidElementError < StandardError; end
  # A block was passed to the method, which it cannot interpreter.
  class UnsupportedBlockError < StandardError; end
  # The condition that was being evaluated inside the block did not evaluate
  # to true within the time limit.
  class TimeoutError < StandardError; end
  # An element could not be located on the page using the given search parameters.
  class NoSuchElementError < StandardError; end

  autoload :ElementContainer, 'appom/element_container'
  autoload :Page, 'appom/page'
  autoload :Wait, 'appom/wait'
  autoload :Section, 'appom/section'
  autoload :ElementFinder, 'appom/element_finder'

  class << self
    attr_accessor :driver
    attr_accessor :max_wait_time

    # Configure appom
    def configure
      yield self
    end

    # Register a new appium driver for Appom.
    # @return [Appium::Driver] A appium driver instance
    def register_driver(&block)
      @driver = block.call()
      setup_exit_handler
    end

    # Creates a new global driver and quits the old one if it exists.
    def start_driver
      @driver.start_driver
    end

    # Reset the device, relaunching the application.
    def reset_driver
      @driver.reset
    end

    # After run all scenario and exit we will quit driver to close appliction under test
    def setup_exit_handler
      main = Process.pid
      at_exit do
        @driver.driver_quit if Process.pid == main
      end
    end
  end

  @max_wait_time = 20
end

World(Appom)

