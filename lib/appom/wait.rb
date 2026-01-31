module Appom
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
  class Wait
    include Logging
    
    # Default timeout in seconds
    DEFAULT_TIMEOUT  = 5
    # Default retry interval in seconds  
    DEFAULT_INTERVAL = 0.25

    # Create a new Wait instance
    #
    # @param [Hash] opts Options for this instance
    # @option opts [Numeric] :timeout (5) Seconds to wait before timing out
    # @option opts [Numeric] :interval (0.25) Seconds to sleep between polls
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
    def until(&block)
      end_time = Time.now + @timeout
      error_message = ""
      last_error = nil
      start_time = Time.now

      log_wait_start("custom condition", @timeout)

      until Time.now > end_time
        begin
          result = yield
          if result
            duration = Time.now - start_time
            log_wait_end("custom condition", duration.round(3), true)
            return result
          end
        rescue => error
          last_error = error
          error_message = error.message
        end

        sleep @interval
      end

      duration = Time.now - start_time
      log_wait_end("custom condition", duration.round(3), false)

      # Raise the last error if it exists, otherwise raise WaitError
      if last_error
        raise last_error
      else
        condition = error_message.empty? ? 'condition' : error_message
        raise WaitError.new(condition, @timeout)
      end
    end
  end
end
