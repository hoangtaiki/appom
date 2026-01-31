# frozen_string_literal: true

module Appom::Retry
  # Default retry configuration
  DEFAULT_RETRY_COUNT = 3
  DEFAULT_RETRY_DELAY = 0.5
  DEFAULT_BACKOFF_MULTIPLIER = 1.5

  class RetryConfig
    attr_accessor :max_attempts, :base_delay, :backoff_multiplier, :max_delay,
                  :retry_on_exceptions, :retry_if, :on_retry

    def initialize
      @max_attempts = DEFAULT_RETRY_COUNT
      @base_delay = DEFAULT_RETRY_DELAY
      @backoff_multiplier = DEFAULT_BACKOFF_MULTIPLIER
      @max_delay = 30 # seconds
      @retry_on_exceptions = [Appom::ElementNotFoundError, Appom::ElementStateError,
                              Appom::WaitError, StandardError,]
      @retry_if = nil
      @on_retry = nil
    end
  end

  class << self
    # Execute a block with retry logic
    def with_retry(config = RetryConfig.new)
      return unless block_given?

      attempt = 1
      delay = config.base_delay

      begin
        yield
      rescue *config.retry_on_exceptions => e
        # Check if we should retry based on custom condition
        raise e if config.retry_if && !config.retry_if.call(e, attempt)

        raise e unless attempt < config.max_attempts

        # Call retry callback if provided
        config.on_retry&.call(e, attempt, delay)

        Kernel.sleep(delay)
        attempt += 1
        delay = [delay * config.backoff_multiplier, config.max_delay].min
        retry
      end
    end

    # Configure retry behavior for element operations
    def configure_element_retry
      config = RetryConfig.new
      yield(config) if block_given?
      config
    end
  end

  # Mixin for adding retry capabilities to classes
  module RetryMethods
    # Retry element finding with exponential backoff
    def find_with_retry(element_name, **retry_options)
      config = build_retry_config(retry_options)

      Appom::Retry.with_retry(config) do
        send(element_name)
      end
    end

    # Retry element interaction (tap, click, etc.)
    def interact_with_retry(element_name, action = :tap, **retry_options)
      config = build_retry_config(retry_options)

      Appom::Retry.with_retry(config) do
        element = send(element_name)
        perform_element_action(element, action, retry_options)
        element
      end
    end

    # Retry getting element text
    def get_text_with_retry(element_name, **retry_options)
      config = build_retry_config(retry_options)

      Appom::Retry.with_retry(config) do
        element = send(element_name)
        text = element.text

        # Validate text if validation block provided
        if retry_options[:validate_text] && !retry_options[:validate_text].call(text)
          raise Appom::ElementStateError.new(element_name, 'valid text', text)
        end

        text
      end
    end

    # Retry waiting for element state
    def wait_for_state_with_retry(element_name, state = :displayed, **retry_options)
      config = build_retry_config(retry_options)

      Appom::Retry.with_retry(config) do
        element = send(element_name)
        validate_element_state(element, element_name, state)
        element
      end
    end

    private

    def perform_element_action(element, action, options)
      case action
      when :tap, :click
        element.tap
      when :clear
        element.clear
      when :send_keys
        element.send_keys(options[:text] || '')
      else
        element.send(action)
      end
    end

    def validate_element_state(element, element_name, state)
      case state
      when :displayed
        validate_displayed_state(element, element_name)
      when :enabled
        validate_enabled_state(element, element_name)
      when :not_displayed
        validate_not_displayed_state(element, element_name)
      else
        raise Appom::ConfigurationError.new('element_state', state, 'Unknown state')
      end
    end

    def validate_displayed_state(element, element_name)
      return if element.displayed?

      raise Appom::ElementStateError.new(element_name, 'displayed', 'not displayed')
    end

    def validate_enabled_state(element, element_name)
      return if element.enabled?

      raise Appom::ElementStateError.new(element_name, 'enabled', 'disabled')
    end

    def validate_not_displayed_state(element, element_name)
      return unless element.displayed?

      raise Appom::ElementStateError.new(element_name, 'not displayed', 'displayed')
    end

    def build_retry_config(options)
      config = Appom::Retry::RetryConfig.new
      config.max_attempts = options.fetch(:max_attempts, DEFAULT_RETRY_COUNT)
      config.base_delay = options.fetch(:base_delay, DEFAULT_RETRY_DELAY)
      config.backoff_multiplier = options.fetch(:backoff_multiplier, DEFAULT_BACKOFF_MULTIPLIER)
      config.max_delay = options.fetch(:max_delay, 30)

      config.retry_on_exceptions = Array(options[:retry_on]) if options[:retry_on]

      config.retry_if = options[:retry_if] if options[:retry_if]

      if options[:on_retry]
        config.on_retry = options[:on_retry]
      elsif respond_to?(:log_warn)
        config.on_retry = lambda { |error, attempt, delay|
          log_warn("Retry attempt #{attempt}/#{config.max_attempts}: #{error.message} (delay: #{delay}s)")
        }
      end

      config
    end
  end
end
