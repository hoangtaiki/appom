# frozen_string_literal: true

# Smart waiting functionality for Appom automation framework
# Provides intelligent wait conditions and strategies
module Appom::SmartWait
  DEFAULT_INTERVAL = 0.25

  # Enhanced wait conditions beyond basic timeout/interval
  class WaitConditions
    class << self
      # Wait for element to be visible/displayed
      def element_visible(element)
        lambda do
          element.displayed?
        rescue StandardError
          false
        end
      end

      # Wait for element to be enabled
      def element_enabled(element)
        lambda do
          element.enabled?
        rescue StandardError
          false
        end
      end

      # Wait for element to be clickable (visible and enabled)
      def element_clickable(element)
        lambda do
          element.displayed? && element.enabled?
        rescue StandardError
          false
        end
      end

      # Wait for text to be present
      def text_present(element, expected_text)
        lambda do
          if expected_text.is_a?(Regexp)
            !(element.text =~ expected_text).nil?
          else
            element.text.include?(expected_text.to_s)
          end
        rescue StandardError
          false
        end
      end

      # Wait for text to change from initial value
      def text_changed(element, initial_text)
        lambda do
          element.text != initial_text
        rescue StandardError
          false
        end
      end

      # Wait for attribute to contain value
      def attribute_contains(element, attribute_name, expected_value)
        lambda do
          (element.attribute(attribute_name) || '').include?(expected_value.to_s)
        rescue StandardError
          false
        end
      end

      # Create custom condition from block
      def custom_condition(&block)
        block
      end

      # Combine conditions with OR logic
      def any_condition(conditions)
        -> { conditions.any?(&:call) }
      end

      # Combine conditions with AND logic
      def all_conditions(conditions)
        -> { conditions.all?(&:call) }
      end

      # Wait for element to be invisible
      def element_invisible(element)
        lambda do
          !element.displayed?
        rescue StandardError
          # Element not found means it's invisible
          true
        end
      end

      # Wait for element attribute to have specific value
      def attribute_equals(element, attribute_name, expected_value)
        lambda do
          actual_value = element.attribute(attribute_name)
          actual_value == expected_value
        rescue StandardError
          false
        end
      end

      # Condition for clickable element (used by factory methods)
      def clickable(element)
        lambda do
          return element.displayed? && element.enabled? if element

          # For factory method usage without element instance
          false
        rescue StandardError
          false
        end
      end

      # Condition for text matching (used by factory methods)
      def text_matches(expected_text, exact: false)
        lambda do |element|
          actual_text = element.text
          if exact
            actual_text == expected_text.to_s
          else
            actual_text.include?(expected_text.to_s)
          end
        rescue StandardError
          false
        end
      end

      # Condition for invisible element (used by factory methods)
      def invisible
        lambda do |element|
          !element.displayed?
        rescue StandardError
          true
        end
      end

      # Condition for element count (used by factory methods)
      def count_equals(expected_count)
        lambda do |elements|
          elements.length == expected_count
        rescue StandardError
          false
        end
      end
    end
  end

  # Enhanced Wait class with smart conditions
  class ConditionalWait < Appom::Wait
    attr_reader :condition, :condition_description

    def initialize(timeout: Appom.max_wait_time, interval: DEFAULT_INTERVAL, condition: nil,
                   description: nil)
      super(timeout: timeout, interval: interval)
      @condition = condition
      @condition_description = description || 'custom condition'
    end

    # Wait for element with specific condition
    def for_element(*find_args, &condition_block)
      condition = condition_block || @condition
      raise Appom::ArgumentError, 'No condition provided' unless condition

      log_wait_start(@condition_description, @timeout)
      start_time = Time.now

      until_with_condition do
        element = _find_element(*find_args)
        if condition.call(element)
          duration = Time.now - start_time
          log_wait_end(@condition_description, duration.round(3), true)
          return element
        end
        false
      rescue StandardError
        # Continue waiting for condition even if element not found initially
        false
      end
    rescue Appom::WaitError
      duration = Time.now - start_time
      log_wait_end(@condition_description, duration.round(3), false)
      raise Appom::ElementNotFoundError.new(
        "#{find_args.join(', ')} with condition: #{@condition_description}", @timeout,
      )
    end

    # Wait for elements collection with condition
    def for_elements(*find_args, &condition_block)
      condition = condition_block || @condition
      raise Appom::ArgumentError, 'No condition provided' unless condition

      log_wait_start("#{@condition_description} (collection)", @timeout)
      start_time = Time.now

      until_with_condition do
        elements = _find_elements(*find_args)
        if condition.call(elements)
          duration = Time.now - start_time
          log_wait_end("#{@condition_description} (collection)", duration.round(3), true)
          return elements
        end
        false
      rescue StandardError
        false
      end
    rescue Appom::WaitError
      duration = Time.now - start_time
      log_wait_end("#{@condition_description} (collection)", duration.round(3), false)
      raise Appom::ElementNotFoundError.new(
        "#{find_args.join(', ')} collection with condition: #{@condition_description}", @timeout,
      )
    end

    # Wait for any of multiple conditions to be met
    def for_any_condition(*conditions_with_elements)
      raise ArgumentError, 'No conditions provided' unless conditions_with_elements.any?

      log_wait_start("any of #{conditions_with_elements.size} conditions", @timeout)
      start_time = Time.now

      until_with_condition do
        conditions_with_elements.each_with_index do |(find_args, condition), index|
          element = _find_element(*find_args)
          if condition.call(element)
            duration = Time.now - start_time
            log_wait_end("condition #{index + 1}", duration.round(3), true)
            return { index: index, element: element, find_args: find_args }
          end
        rescue StandardError
          # Continue to next condition
        end
        false
      end
    rescue Appom::WaitError
      duration = Time.now - start_time
      log_wait_end('any condition', duration.round(3), false)
      descriptions = conditions_with_elements.map.with_index do |(find_args, _), i|
        "#{i + 1}: #{find_args.join(', ')}"
      end
      raise Appom::ElementNotFoundError.new("any of: #{descriptions.join('; ')}", @timeout)
    end

    # Wait until condition becomes true
    def wait_until(condition, timeout: @timeout, interval: @interval, backoff_factor: nil,
                   max_interval: nil)
      start_time = Time.now
      last_error = nil
      current_interval = interval

      loop do
        result = evaluate_condition_safely(condition, last_error)
        return true if result[:success]

        last_error = result[:error]

        check_timeout_reached(start_time, timeout, last_error)

        sleep current_interval
        current_interval = apply_backoff(current_interval, backoff_factor, max_interval)
      end
    end

    # Wait while condition remains true
    def wait_while(condition, timeout: @timeout, interval: @interval)
      start_time = Time.now
      while condition.call
        raise Appom::TimeoutError, "Condition remained true for #{timeout}s" if Time.now - start_time > timeout

        sleep interval
      end
      true
    end

    # Wait for condition to remain stable for specified duration
    def wait_for_stable_condition(condition, stable_duration: 1.0, timeout: @timeout,
                                  interval: @interval)
      start_time = Time.now
      stable_start = nil

      loop do
        begin
          if condition.call
            stable_start ||= Time.now
            return true if Time.now - stable_start >= stable_duration
          else
            stable_start = nil
          end
        rescue StandardError
          stable_start = nil
        end

        if Time.now - start_time > timeout
          raise Appom::TimeoutError,
                "Condition did not remain stable for #{stable_duration}s within #{timeout}s"
        end

        sleep interval
      end
    end

    private

    def evaluate_condition_safely(condition, last_error)
      success = condition.call
      { success: success, error: last_error }
    rescue StandardError => e
      { success: false, error: e }
    end

    def check_timeout_reached(start_time, timeout, last_error)
      return unless Time.now - start_time > timeout
      raise last_error if last_error

      raise Appom::TimeoutError, "Condition not met within #{timeout}s"
    end

    def apply_backoff(current_interval, backoff_factor, max_interval)
      if backoff_factor && max_interval
        [current_interval * backoff_factor, max_interval].min
      else
        current_interval
      end
    end

    # Wait until condition becomes true with exponential backoff
    def wait_until_with_backoff(condition, timeout: @timeout, interval: @interval,
                                backoff_factor: 2, max_interval: 5)
      wait_until(condition, timeout: timeout, interval: interval, backoff_factor: backoff_factor,
                            max_interval: max_interval,)
    end

    def until_with_condition
      timeout = @timeout || 5
      start_time = Time.now
      loop do
        return true if yield
        raise Appom::WaitError, 'Timeout waiting for condition' if (Time.now - start_time) > timeout

        sleep 0.1
      end
    end

    def _find_element(*find_args)
      # Use the same finding logic as ElementFinder
      if respond_to?(:page)
        page.find_element(*find_args)
      else
        Appom.driver.find_element(*find_args)
      end
    end

    def _find_elements(*find_args)
      if respond_to?(:page)
        page.find_elements(*find_args)
      else
        Appom.driver.find_elements(*find_args)
      end
    end
  end

  # Factory methods for creating conditional waits
  class << self
    # Create a wait with clickable condition
    def until_clickable(*find_args, timeout: Appom.max_wait_time)
      wait = ConditionalWait.new(
        timeout: timeout,
        condition: WaitConditions.clickable(nil),
        description: 'clickable',
      )
      wait.for_element(*find_args)
    end

    # Create a wait for specific text
    def until_text_matches(*find_args, text:, exact: false, timeout: Appom.max_wait_time)
      wait = ConditionalWait.new(
        timeout: timeout,
        condition: WaitConditions.text_matches(text, exact: exact),
        description: "text #{exact ? 'equals' : 'matches'} '#{text}'",
      )
      wait.for_element(*find_args)
    end

    # Create a wait for invisible element
    def until_invisible(*find_args, timeout: Appom.max_wait_time)
      wait = ConditionalWait.new(
        timeout: timeout,
        condition: WaitConditions.invisible,
        description: 'invisible',
      )
      wait.for_element(*find_args)
    end

    # Create a wait for element count
    def until_count_equals(*find_args, count:, timeout: Appom.max_wait_time)
      wait = ConditionalWait.new(
        timeout: timeout,
        condition: WaitConditions.count_equals(count),
        description: "count equals #{count}",
      )
      wait.for_elements(*find_args)
    end

    # Create a wait for custom condition
    def until_condition(*find_args, timeout: Appom.max_wait_time,
                        description: 'custom condition', &condition_block)
      wait = ConditionalWait.new(
        timeout: timeout,
        condition: condition_block,
        description: description,
      )
      wait.for_element(*find_args, &condition_block)
    end
  end

  # Module-level convenience methods
  module_function

  def wait_until(condition, timeout: Appom.max_wait_time, backoff_factor: nil, max_interval: nil)
    wait = ConditionalWait.new(timeout: timeout)
    if backoff_factor && max_interval
      wait.wait_until_with_backoff(condition, timeout: timeout, backoff_factor: backoff_factor,
                                              max_interval: max_interval,)
    else
      wait.wait_until(condition, timeout: timeout)
    end
  end

  def wait_for_element_visible(element, timeout: Appom.max_wait_time)
    condition = WaitConditions.element_visible(element)
    wait_until(condition, timeout: timeout)
  end

  def wait_for_element_clickable(element, timeout: Appom.max_wait_time)
    condition = WaitConditions.element_clickable(element)
    wait_until(condition, timeout: timeout)
  end

  def wait_for_text_present(element, text, timeout: Appom.max_wait_time)
    condition = WaitConditions.text_present(element, text)
    wait_until(condition, timeout: timeout)
  end

  def wait_for_text_to_change(element, initial_text, timeout: Appom.max_wait_time)
    condition = WaitConditions.text_changed(element, initial_text)
    wait_until(condition, timeout: timeout)
  end

  def wait_for_stable_element(element, timeout: Appom.max_wait_time, stable_duration: 1.0)
    condition = -> { element.displayed? && element.enabled? }
    wait = ConditionalWait.new(timeout: timeout)
    wait.wait_for_stable_condition(condition, stable_duration: stable_duration, timeout: timeout)
  end
end
