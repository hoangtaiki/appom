module Appom
  module Retry
    # Default retry configuration
    DEFAULT_RETRY_COUNT = 3
    DEFAULT_RETRY_DELAY = 0.5
    DEFAULT_BACKOFF_MULTIPLIER = 1.5

    class RetryConfig
      attr_accessor :max_attempts, :base_delay, :backoff_multiplier, :max_delay
      attr_accessor :retry_on_exceptions, :retry_if, :on_retry

      def initialize
        @max_attempts = DEFAULT_RETRY_COUNT
        @base_delay = DEFAULT_RETRY_DELAY
        @backoff_multiplier = DEFAULT_BACKOFF_MULTIPLIER
        @max_delay = 30 # seconds
        @retry_on_exceptions = [ElementNotFoundError, WaitError, StandardError]
        @retry_if = nil
        @on_retry = nil
      end
    end

    class << self
      # Execute a block with retry logic
      def with_retry(config = RetryConfig.new)
        if block_given?
          attempt = 1
          delay = config.base_delay

          begin
            yield
          rescue *config.retry_on_exceptions => e
            # Check if we should retry based on custom condition
            if config.retry_if && !config.retry_if.call(e, attempt)
              raise e
            end

            if attempt < config.max_attempts
              # Call retry callback if provided
              config.on_retry&.call(e, attempt, delay)
              
              sleep(delay)
              attempt += 1
              delay = [delay * config.backoff_multiplier, config.max_delay].min
              retry
            else
              raise e
            end
          end
        end
      end

      # Configure retry behavior for element operations
      def configure_element_retry(&block)
        config = RetryConfig.new
        block.call(config) if block_given?
        config
      end
    end

    # Mixin for adding retry capabilities to classes
    module RetryMethods
      # Retry element finding with exponential backoff
      def find_with_retry(element_name, **retry_options)
        config = build_retry_config(retry_options)
        
        Retry.with_retry(config) do
          send(element_name)
        end
      end

      # Retry element interaction (tap, click, etc.)
      def interact_with_retry(element_name, action = :tap, **retry_options)
        config = build_retry_config(retry_options)
        
        Retry.with_retry(config) do
          element = send(element_name)
          case action
          when :tap, :click
            element.tap
          when :clear
            element.clear
          when :send_keys
            element.send_keys(retry_options[:text] || '')
          else
            element.send(action)
          end
          element
        end
      end

      # Retry getting element text
      def get_text_with_retry(element_name, **retry_options)
        config = build_retry_config(retry_options)
        
        Retry.with_retry(config) do
          element = send(element_name)
          text = element.text
          
          # Validate text if validation block provided
          if retry_options[:validate_text] && !retry_options[:validate_text].call(text)
            raise ElementStateError.new(element_name, 'valid text', text)
          end
          
          text
        end
      end

      # Retry waiting for element state
      def wait_for_state_with_retry(element_name, state = :displayed, **retry_options)
        config = build_retry_config(retry_options)
        
        Retry.with_retry(config) do
          element = send(element_name)
          
          case state
          when :displayed
            unless element.displayed?
              raise ElementStateError.new(element_name, 'displayed', 'not displayed')
            end
          when :enabled
            unless element.enabled?
              raise ElementStateError.new(element_name, 'enabled', 'disabled')
            end
          when :not_displayed
            if element.displayed?
              raise ElementStateError.new(element_name, 'not displayed', 'displayed')
            end
          else
            raise ConfigurationError.new('element_state', state, 'Unknown state')
          end
          
          element
        end
      end

      private

      def build_retry_config(options)
        config = Appom::Retry::RetryConfig.new
        config.max_attempts = options.fetch(:max_attempts, DEFAULT_RETRY_COUNT)
        config.base_delay = options.fetch(:base_delay, DEFAULT_RETRY_DELAY)
        config.backoff_multiplier = options.fetch(:backoff_multiplier, DEFAULT_BACKOFF_MULTIPLIER)
        config.max_delay = options.fetch(:max_delay, 30)
        
        if options[:retry_on]
          config.retry_on_exceptions = Array(options[:retry_on])
        end
        
        if options[:retry_if]
          config.retry_if = options[:retry_if]
        end
        
        if options[:on_retry]
          config.on_retry = options[:on_retry]
        elsif defined?(log_warn)
          config.on_retry = ->(error, attempt, delay) {
            log_warn("Retry attempt #{attempt}/#{config.max_attempts}: #{error.message} (delay: #{delay}s)")
          }
        end
        
        config
      end
    end
  end
end