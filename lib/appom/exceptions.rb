# frozen_string_literal: true

module Appom
  # Base exception for all Appom-related errors
  class AppomError < StandardError
    attr_reader :context

    def initialize(message = nil, context = {})
      super(message)
      @context = context
    end

    def detailed_message
      message_parts = [message]
      message_parts << "Context: #{context}" unless context.empty?
      message_parts.join("\n")
    end
  end

  # Element-related errors
  class ElementError < AppomError; end

  # Raised when an element was defined without proper arguments
  class InvalidElementError < ElementError
    def initialize(element_name = nil)
      message = 'Element'
      message += " '#{element_name}'" if element_name
      message += ' was defined without proper selector arguments'
      super(message)
    end
  end

  # Raised when an element cannot be found within the timeout
  class ElementNotFoundError < ElementError
    def initialize(selector = nil, timeout = nil)
      message = 'Element not found'
      message += " with selector: #{selector}" if selector
      message += " within #{timeout}s" if timeout
      super(message, { selector: selector, timeout: timeout })
    end
  end

  # Raised when an element is found but not in the expected state
  class ElementStateError < ElementError
    def initialize(element_name, expected_state, actual_state = nil)
      message = "Element '#{element_name}' expected to be #{expected_state}"
      message += " but was #{actual_state}" if actual_state
      super(message, { element: element_name, expected: expected_state, actual: actual_state })
    end
  end

  # Wait-related errors
  class WaitError < AppomError
    attr_reader :condition, :timeout

    def initialize(condition, timeout)
      @condition = condition
      @timeout = timeout
      super("Wait condition '#{condition}' not met within #{timeout}s",
            { condition: condition, timeout: timeout })
    end
  end

  # Driver-related errors
  class DriverError < AppomError; end

  # Raised when driver is not properly initialized
  class DriverNotInitializedError < DriverError
    def initialize
      super('Appium driver not initialized. Please call Appom.register_driver first.')
    end
  end

  # Raised when driver operations fail
  class DriverOperationError < DriverError
    attr_reader :operation, :cause

    def initialize(operation, cause = nil)
      @operation = operation
      @cause = cause
      message = "Driver operation '#{operation}' failed"
      message += ": #{cause}" if cause
      super(message, { operation: operation, cause: cause })
    end
  end

  # Configuration-related errors
  class ConfigurationError < AppomError
    def initialize(setting, value = nil, reason = nil)
      message = "Invalid configuration for '#{setting}'"
      message += " (value: #{value})" if value
      message += ": #{reason}" if reason
      super(message, { setting: setting, value: value, reason: reason })
    end
  end

  # Block/syntax errors
  class UnsupportedBlockError < AppomError
    def initialize(method_name, type)
      super("#{type}##{method_name} does not accept blocks",
            { method: method_name, type: type })
    end
  end

  # Section-related errors
  class SectionError < AppomError; end

  # Invalid section definition error
  class InvalidSectionError < SectionError
    def initialize(reason)
      super("Invalid section definition: #{reason}")
    end
  end

  # Timeout and waiting errors
  class TimeoutError < AppomError
    def initialize(message = 'Operation timed out')
      super
    end
  end
end
