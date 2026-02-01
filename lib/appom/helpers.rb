# frozen_string_literal: true

require 'appom/retry'

# Helper utilities for Appom automation framework
# Provides common interaction patterns and utility methods
module Appom::Helpers
  # Get the performance module, allowing for test mocking
  def self.performance_module
    defined?(Performance) ? Performance : Appom::Performance
  end

  # Common element interaction patterns
  module ElementHelpers
    include Appom::Retry::RetryMethods

    # Tap an element and wait for it to be enabled
    def tap_and_wait(element_name, timeout: nil)
      Appom::Helpers.performance_module.time_operation("tap_and_wait_#{element_name}") do
        timeout ||= Appom.max_wait_time
        element = send(element_name)
        element.tap

        # Wait for element to be enabled if it has an enable checker
        send("#{element_name}_enable") if respond_to?(:"#{element_name}_enable")
        element
      end
    end

    # Get element text with retry
    def get_text_with_retry(element_name, retries: 3)
      attempt = 0
      begin
        send(element_name).text
      rescue StandardError => e
        attempt += 1
        raise e unless attempt <= retries

        sleep(0.5)
        retry
      end
    end

    # Wait for element to be visible and tap
    def wait_and_tap(element_name, timeout: nil) # rubocop:disable Lint/UnusedMethodArgument
      Appom::Helpers.performance_module.time_operation("wait_and_tap_#{element_name}") do
        method_name = "has_#{element_name}"
        send(method_name) if respond_to?(method_name)
        send(element_name).tap
      end
    end

    # Get element attribute with fallback
    def get_attribute_with_fallback(element_name, attribute, fallback_value = nil)
      send(element_name).attribute(attribute) || fallback_value
    rescue StandardError => e
      log_warn("Failed to get attribute #{attribute} for #{element_name}: #{e.message}")
      fallback_value
    end

    # Check if element contains text
    def element_contains_text?(element_name, text)
      element_text = get_text_with_retry(element_name)
      element_text&.include?(text) || false
    end

    # Basic scroll method for scrolling in specified direction
    def scroll(direction = :down)
      # Basic implementation - actual implementation would depend on platform
      case direction
      when :down
        Appom.driver.execute_script('mobile: scrollGesture', {
                                      left: 100, top: 100, width: 200, height: 200,
                                      direction: 'down', percent: 3.0,
                                    })
      when :up
        Appom.driver.execute_script('mobile: scrollGesture', {
                                      left: 100, top: 100, width: 200, height: 200,
                                      direction: 'up', percent: 3.0,
                                    })
      end
    rescue StandardError => e
      # Fallback scroll for different platforms
      log_warn("Scroll gesture failed: #{e.message}")
    end

    # Scroll to element if needed and tap
    def scroll_to_and_tap(element_name, direction: :down)
      max_scrolls = 5
      scrolls = 0

      while scrolls < max_scrolls
        return wait_and_tap(element_name) if respond_to?("has_#{element_name}") && send("has_#{element_name}")

        scroll(direction)
        scrolls += 1
      end

      raise Appom::ElementNotFoundError.new(element_name, "after #{max_scrolls} scrolls")
    end
  end

  # Common wait patterns
  module WaitHelpers
    include Appom::Retry::RetryMethods

    # Wait for element to be clickable (visible and enabled)
    def wait_for_clickable(element_name, timeout: nil)
      timeout ||= Appom.max_wait_time
      find_args = send("#{element_name}_params")
      Appom::SmartWait.until_clickable(*find_args, timeout: timeout)
    end

    # Wait for element text to match pattern
    def wait_for_text_match(element_name, text, exact: false, timeout: nil)
      timeout ||= Appom.max_wait_time
      find_args = send("#{element_name}_params")
      Appom::SmartWait.until_text_matches(*find_args, text: text, exact: exact, timeout: timeout)
    end

    # Wait for element to become invisible
    def wait_for_invisible(element_name, timeout: nil)
      timeout ||= Appom.max_wait_time
      find_args = send("#{element_name}_params")
      Appom::SmartWait.until_invisible(*find_args, timeout: timeout)
    end

    # Wait for elements collection to have specific count
    def wait_for_count(elements_name, count, timeout: nil)
      timeout ||= Appom.max_wait_time
      find_args = send("#{elements_name}_params")
      Appom::SmartWait.until_count_equals(*find_args, count: count, timeout: timeout)
    end

    # Advanced: Wait for custom condition on element
    def wait_for_condition(element_name, description: 'custom condition', timeout: nil, &condition_block)
      timeout ||= Appom.max_wait_time
      find_args = send("#{element_name}_params")
      Appom::SmartWait.until_condition(*find_args, timeout: timeout, description: description, &condition_block)
    end

    # Wait for any of multiple elements to appear
    def wait_for_any(*element_names, timeout: nil)
      timeout ||= Appom.max_wait_time
      wait = Appom::Wait.new(timeout: timeout)

      wait.until do
        element_names.each do |element_name|
          return element_name if respond_to?("has_#{element_name}") && send("has_#{element_name}")
        end
        false
      end
    rescue Appom::WaitError
      raise Appom::ElementNotFoundError.new("any of: #{element_names.join(', ')}", timeout)
    end

    # Wait for element to disappear
    def wait_for_disappear(element_name, timeout: nil)
      if respond_to?("has_no_#{element_name}")
        send("has_no_#{element_name}")
      else
        timeout ||= Appom.max_wait_time
        wait = Appom::Wait.new(timeout: timeout)
        wait.until do
          send(element_name)
          false
        rescue Appom::ElementNotFoundError
          true
        end
      end
    end

    # Wait for text to appear in element
    def wait_for_text_in_element(element_name, expected_text, timeout: nil)
      timeout ||= Appom.max_wait_time
      wait = Appom::Wait.new(timeout: timeout)

      wait.until do
        element_text = get_text_with_retry(element_name, retries: 1)
        element_text&.include?(expected_text)
      rescue StandardError
        false
      end
    end
  end

  # Debugging helpers
  module DebugHelpers
    # Take screenshot with automatic naming
    def take_debug_screenshot(prefix = 'debug')
      Screenshot.capture(prefix)
    end

    # Take screenshot of specific element
    def take_element_screenshot(element_name, prefix = 'element')
      element = send(element_name)
      Screenshot.capture("#{prefix}_#{element_name}", element: element)
    rescue StandardError => e
      log_error("Failed to take element screenshot: #{e.message}")
      nil
    end

    # Take before/after screenshots around an action
    def screenshot_action(action_name, &)
      Screenshot.capture_before_after(action_name, &)
    end

    # Take screenshot sequence during complex interaction
    def screenshot_sequence(name, interval: 1.0, max_duration: 10.0, &)
      Screenshot.capture_sequence(name, interval: interval, max_duration: max_duration, &)
    end

    # Take screenshot on test failure with exception info
    def screenshot_failure(test_name, exception = nil)
      Screenshot.capture_on_failure(test_name, exception)
    end

    # Dump current page source for debugging
    def dump_page_source(prefix = 'page_source')
      return unless respond_to?(:driver) && driver

      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      filename = "#{prefix}_#{timestamp}.xml"

      begin
        File.write(filename, driver.page_source)
        log_info("Page source saved: #{filename}")
        filename
      rescue StandardError => e
        log_error("Failed to save page source: #{e.message}")
        nil
      end
    end

    # Get information about all elements matching a locator
    def debug_elements_info(*find_args)
      elements = _all(*find_args)
      info = elements.map.with_index do |element, index|
        {
          index: index,
          tag_name: element.tag_name,
          text: element.text.to_s.strip,
          displayed: element.displayed?,
          enabled: element.enabled?,
          location: element.location,
          size: element.size,
        }
      rescue StandardError => e
        { index: index, error: e.message }
      end

      log_info("Found #{elements.count} elements matching #{find_args.join(', ')}")
      info.each { |element_info| log_debug("Element info: #{element_info}") }
      info
    rescue StandardError => e
      log_error("Failed to get elements info: #{e.message}")
      []
    end
  end

  # Phase 2 Performance monitoring helpers
  module PerformanceHelpers
    # Time any element operation
    def time_element_operation(element_name, operation, &)
      Appom::Helpers.performance_module.time_operation("#{element_name}_#{operation}", &)
    end

    # Get performance stats for specific element operations
    def element_performance_stats(element_name = nil)
      if element_name
        Appom::Helpers.performance_module.stats.select { |name, _| name.include?(element_name.to_s) }
      else
        Appom::Helpers.performance_module.summary
      end
    end
  end

  # Phase 2 Visual testing helpers
  module VisualHelpers
    # Take screenshot with element highlighted
    def screenshot_with_highlight(element_name, filename: nil) # rubocop:disable Lint/UnusedMethodArgument
      element = send(element_name)
      Visual.test_helpers.highlight_element(element)
    end

    # Visual regression test for current page
    def visual_regression_test(test_name, options = {})
      Visual.regression_test(test_name, options)
    end

    # Wait for visual stability before continuing
    def wait_for_visual_stability(element_name = nil, **)
      element = element_name ? send(element_name) : nil
      Visual.test_helpers.wait_for_visual_stability(element: element, **)
    end
  end

  # Phase 2 Element state tracking helpers
  module ElementStateHelpers
    # Start tracking an element's state changes
    def track_element_state(element_name, context: {})
      element = send(element_name)
      ElementState.track_element(element, name: element_name.to_s, context: context)
    end

    # Wait for element state to change
    def wait_for_element_state_change(element_name, expected_changes: {}, **)
      element_id = element_name.to_s
      ElementState.wait_for_state_change(element_id, expected_changes: expected_changes, **)
    end

    # Get current state of tracked element
    def element_current_state(element_name)
      ElementState.element_state(element_name.to_s)
    end
  end

  # Include all helper modules
  def self.included(klass)
    klass.include ElementHelpers
    klass.include WaitHelpers
    klass.include DebugHelpers
    klass.include PerformanceHelpers
    klass.include VisualHelpers
    klass.include ElementStateHelpers
    klass.include Appom::Logging
  end
end
