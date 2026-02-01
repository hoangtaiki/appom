# frozen_string_literal: true

# Provides wait functionality with configurable timeout and retry interval.
#
# The Wait class is used throughout Appom to wait for conditions to become true,
# such as waiting for elements to appear or disappear, or for elements to reach
# a certain state.
#
# @example Basic wait usage
#   wait = Appom::Wait.new(timeout: 10, interval: 0.5)
#   result = wait.until { some_condition }
#
# @example Wait for element to be displayed
#   wait = Appom::Wait.new(timeout: 5)
#   wait.until { element.displayed? }
#
# @since 0.1.0
# @author Harry.Tran
class Appom::Wait
  include Appom::Logging

  # Default timeout in seconds
  DEFAULT_TIMEOUT  = 5
  # Default retry interval in seconds
  DEFAULT_INTERVAL = 0.25

  # @!attribute [r] timeout
  #   @return [Numeric] The timeout value in seconds
  # @!attribute [r] interval
  #   @return [Numeric] The interval between retries in seconds
  attr_reader :timeout, :interval

  # Create a new Wait instance
  #
  # @param opts [Hash] Options for this instance
  # @option opts [Numeric] :timeout (5) Seconds to wait before timing out
  # @option opts [Numeric] :interval (0.25) Seconds to sleep between polls
  # @return [Wait] A new Wait instance
  #
  # @example Create wait with custom timeout
  #   wait = Appom::Wait.new(timeout: 10, interval: 1.0)
  def initialize(opts = {})
    @timeout  = opts.fetch(:timeout, DEFAULT_TIMEOUT)
    @interval = opts.fetch(:interval, DEFAULT_INTERVAL)
  end

  # Wait until the given block returns a truthy value
  #
  # @yield [] Block to execute repeatedly until it returns true
  # @return [Object] The result of the block when it returns truthy
  # @raise [WaitError] If the timeout is reached before condition is met
  # @raise [AppomError] Re-raises any Appom-specific errors from the block
  #
  # @example Wait for element to appear
  #   wait.until { page.find_element(:id, 'button') }
  #
  # @example Wait with exception handling
  #   wait.until do
  #     element = page.find_element(:id, 'button')
  #     element.displayed? && element.enabled?
  #   end
  def until(&)
    end_time = Time.now + @timeout
    error_message = ''
    last_error = nil
    start_time = Time.now

    log_wait_start('custom condition', @timeout)

    until Time.now > end_time
      begin
        result = yield
        if result
          duration = Time.now - start_time
          log_wait_end('custom condition', duration.round(3), success: true)
          return result
        end
      rescue StandardError => e
        last_error = e
        error_message = e.message
      end

      sleep @interval
    end

    duration = Time.now - start_time
    log_wait_end('custom condition', duration.round(3), success: false)

    # Handle exceptions differently based on type
    if last_error.is_a?(StandardError) && last_error.instance_of?(StandardError)
      # Wrap StandardError in WaitError with message included
      condition = "condition (last error: #{error_message})"
      raise Appom::WaitError.new(condition, @timeout)
    elsif last_error
      # Raise specific exceptions directly (ArgumentError, RuntimeError, etc.)
      raise last_error
    else
      # No exceptions, just condition never became true
      condition = error_message.empty? ? 'condition' : error_message
      raise Appom::WaitError.new(condition, @timeout)
    end
  end
end
