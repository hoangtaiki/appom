module Appom
  module SmartWait
    DEFAULT_INTERVAL = 0.25

    # Enhanced wait conditions beyond basic timeout/interval
    class WaitConditions
      class << self
        # Wait for element to be visible/displayed  
        def element_visible(element)
          -> do
            begin
              element.displayed?
            rescue => e
              false
            end
          end
        end

        # Wait for element to be enabled
        def element_enabled(element)
          -> do
            begin
              element.enabled?
            rescue => e
              false
            end
          end
        end

        # Wait for element to be clickable (visible and enabled)
        def element_clickable(element)
          -> do
            begin
              element.displayed? && element.enabled?
            rescue => e
              false
            end
          end
        end

        # Wait for text to be present
        def text_present(element, expected_text)
          -> do
            begin
              if expected_text.is_a?(Regexp)
                !!(element.text =~ expected_text)
              else
                element.text.include?(expected_text.to_s)
              end
            rescue => e
              false
            end
          end
        end

        # Wait for text to change from initial value
        def text_changed(element, initial_text)
          -> do
            begin
              element.text != initial_text
            rescue => e
              false
            end
          end
        end

        # Wait for attribute to contain value
        def attribute_contains(element, attribute_name, expected_value)
          -> do
            begin
              (element.attribute(attribute_name) || '').include?(expected_value.to_s)
            rescue => e
              false
            end
          end
        end

        # Create custom condition from block
        def custom_condition(&block)
          -> { block.call }
        end

        # Combine conditions with OR logic
        def any_condition(conditions)
          -> { conditions.any? { |condition| condition.call } }
        end

        # Combine conditions with AND logic  
        def all_conditions(conditions)
          -> { conditions.all? { |condition| condition.call } }
        end

        # Wait for element to be invisible
        def element_invisible(element)
          -> do
            begin
              !element.displayed?
            rescue => e
              # Element not found means it's invisible
              true
            end
          end
        end

        # Wait for element attribute to have specific value
        def attribute_equals(element, attribute_name, expected_value)
          -> do
            begin
              actual_value = element.attribute(attribute_name)
              actual_value == expected_value
            rescue => e
              false
            end
          end
        end
      end
    end

    # Enhanced Wait class with smart conditions
    class ConditionalWait < Appom::Wait
      attr_reader :condition, :condition_description

      def initialize(timeout: Appom.max_wait_time, interval: DEFAULT_INTERVAL, condition: nil, description: nil)
        super(timeout: timeout, interval: interval)
        @condition = condition
        @condition_description = description || 'custom condition'
      end

      # Wait for element with specific condition
      def for_element(*find_args, &condition_block)
        condition = condition_block || @condition
        raise ArgumentError, 'No condition provided' unless condition

        log_wait_start(@condition_description, @timeout)
        start_time = Time.now

        until_with_condition do
          begin
            element = _find_element(*find_args)
            if condition.call(element)
              duration = Time.now - start_time
              log_wait_end(@condition_description, duration.round(3), true)
              return element
            end
            false
          rescue => e
            # Continue waiting for condition even if element not found initially
            false
          end
        end
      rescue WaitError => e
        duration = Time.now - start_time
        log_wait_end(@condition_description, duration.round(3), false)
        raise ElementNotFoundError.new("#{find_args.join(', ')} with condition: #{@condition_description}", @timeout)
      end

      # Wait for elements collection with condition
      def for_elements(*find_args, &condition_block)
        condition = condition_block || @condition
        raise ArgumentError, 'No condition provided' unless condition

        log_wait_start("#{@condition_description} (collection)", @timeout)
        start_time = Time.now

        until_with_condition do
          begin
            elements = _find_elements(*find_args)
            if condition.call(elements)
              duration = Time.now - start_time
              log_wait_end("#{@condition_description} (collection)", duration.round(3), true)
              return elements
            end
            false
          rescue => e
            false
          end
        end
      rescue WaitError => e
        duration = Time.now - start_time
        log_wait_end("#{@condition_description} (collection)", duration.round(3), false)
        raise ElementNotFoundError.new("#{find_args.join(', ')} collection with condition: #{@condition_description}", @timeout)
      end

      # Wait for any of multiple conditions to be met
      def for_any_condition(*conditions_with_elements)
        raise ArgumentError, 'No conditions provided' unless conditions_with_elements.any?

        log_wait_start("any of #{conditions_with_elements.size} conditions", @timeout)
        start_time = Time.now

        until_with_condition do
          conditions_with_elements.each_with_index do |(find_args, condition), index|
            begin
              element = _find_element(*find_args)
              if condition.call(element)
                duration = Time.now - start_time
                log_wait_end("condition #{index + 1}", duration.round(3), true)
                return { index: index, element: element, find_args: find_args }
              end
            rescue => e
              # Continue to next condition
            end
          end
          false
        end
      rescue WaitError => e
        duration = Time.now - start_time
        log_wait_end("any condition", duration.round(3), false)
        descriptions = conditions_with_elements.map.with_index { |(find_args, _), i| "#{i + 1}: #{find_args.join(', ')}" }
        raise ElementNotFoundError.new("any of: #{descriptions.join('; ')}", @timeout)
      end

      # Wait until condition becomes true
      def wait_until(condition, timeout: @timeout, interval: @interval, backoff_factor: nil, max_interval: nil)
        start_time = Time.now
        last_error = nil
        current_interval = interval
        
        loop do
          begin
            return true if condition.call
          rescue => e
            last_error = e
            # Continue trying on exceptions
          end
          
          if Time.now - start_time > timeout
            if last_error
              raise last_error
            else
              raise Appom::Exceptions::TimeoutError, "Condition not met within #{timeout}s"
            end
          end
          
          sleep current_interval
          
          # Apply backoff if specified
          if backoff_factor && max_interval
            current_interval = [current_interval * backoff_factor, max_interval].min
          end
        end
      end

      # Wait until condition becomes true with exponential backoff
      def wait_until_with_backoff(condition, timeout: @timeout, interval: @interval, backoff_factor: 2, max_interval: 5)
        start_time = Time.now
        current_interval = interval
        last_error = nil
        
        loop do
          begin
            return true if condition.call
          rescue => e
            last_error = e
            # Continue trying on exceptions
          end
          
          if Time.now - start_time > timeout
            if last_error
              raise last_error
            else
              raise Appom::Exceptions::TimeoutError, "Condition not met within #{timeout}s"
            end
          end
          
          sleep current_interval
          current_interval = [current_interval * backoff_factor, max_interval].min
        end
      end

      # Wait while condition remains true  
      def wait_while(condition, timeout: @timeout, interval: @interval)
        start_time = Time.now
        while condition.call
          if Time.now - start_time > timeout
            raise Appom::Exceptions::TimeoutError, "Condition remained true for #{timeout}s"
          end
          sleep interval
        end
        true
      end

      # Wait for condition to remain stable for specified duration
      def wait_for_stable_condition(condition, stable_duration: 1.0, timeout: @timeout, interval: @interval)
        start_time = Time.now
        stable_start = nil

        loop do
          begin
            if condition.call
              stable_start ||= Time.now
              if Time.now - stable_start >= stable_duration
                return true
              end
            else
              stable_start = nil
            end
          rescue => e
            stable_start = nil
          end

          if Time.now - start_time > timeout
            raise Appom::Exceptions::TimeoutError, "Condition not stable for #{stable_duration}s within #{timeout}s"
          end

          sleep interval
        end
      end

      private

      def until_with_condition(&block)
        until block.call
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
          description: 'clickable'
        )
        wait.for_element(*find_args)
      end

      # Create a wait for specific text
      def until_text_matches(*find_args, text:, exact: false, timeout: Appom.max_wait_time)
        wait = ConditionalWait.new(
          timeout: timeout,
          condition: WaitConditions.text_matches(text, exact: exact),
          description: "text #{exact ? 'equals' : 'matches'} '#{text}'"
        )
        wait.for_element(*find_args)
      end

      # Create a wait for invisible element
      def until_invisible(*find_args, timeout: Appom.max_wait_time)
        wait = ConditionalWait.new(
          timeout: timeout,
          condition: WaitConditions.invisible,
          description: 'invisible'
        )
        wait.for_element(*find_args)
      end

      # Create a wait for element count
      def until_count_equals(*find_args, count:, timeout: Appom.max_wait_time)
        wait = ConditionalWait.new(
          timeout: timeout,
          condition: WaitConditions.count_equals(count),
          description: "count equals #{count}"
        )
        wait.for_elements(*find_args)
      end

      # Create a wait for custom condition
      def until_condition(*find_args, timeout: Appom.max_wait_time, description: 'custom condition', &condition_block)
        wait = ConditionalWait.new(
          timeout: timeout,
          condition: condition_block,
          description: description
        )
        wait.for_element(*find_args, &condition_block)
      end
    end

    # Module-level convenience methods
    module_function

    def wait_until(condition, timeout: Appom.max_wait_time, backoff_factor: nil, max_interval: nil)
      wait = ConditionalWait.new(timeout: timeout)
      if backoff_factor && max_interval
        wait.wait_until_with_backoff(condition, timeout: timeout, backoff_factor: backoff_factor, max_interval: max_interval)
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
end