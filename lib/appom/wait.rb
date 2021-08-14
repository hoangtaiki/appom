module Appom
  class Wait
    DEFAULT_TIMEOUT  = 5
    DEFAULT_INTERVAL = 0.25

    ##
    # Create a new Wait instance
    #
    # @param [Hash] opts Options for this instance
    # @option opts [Numeric] :timeout (5) Seconds to wait before timing out.
    # @option opts [Numeric] :interval (0.25) Seconds to sleep between polls.
    #
    def initialize(opts = {})
      @timeout  = opts.fetch(:timeout, DEFAULT_TIMEOUT)
      @interval = opts.fetch(:interval, DEFAULT_INTERVAL)
    end

    ##
    # Wait until the given block returns a true value.
    #
    # @raise [Error::TimeOutError]
    # @return [Object] the result of the block
    #
    def until
      end_time = Time.now + @timeout
      error_message = ""

      until Time.now > end_time
        begin
          result = yield
          return result if result
        rescue => error
          error_message = error.message
        end

        sleep @interval
      end

      raise StandardError, error_message
    end
  end
end
