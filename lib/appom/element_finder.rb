module Appom
  module ElementFinder
    include Logging

    def self.included(klass)
      # Include cache-aware finder if caching is enabled
      begin
        if Appom.cache_config[:enabled]
          klass.include(ElementCache::CacheAwareFinder)
        end
      rescue => e
        # Continue without caching if it fails to load
      end
    end

    # Find an element
    def _find(*find_args)
      args, text, visible = deduce_element_args(find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      
      log_debug("Finding element", { args: args, text: text, visible: visible })
      start_time = Time.now

      wait.until do
        elements = page.find_elements(*args)
        elements.each do |element|
          if !visible.nil? && !text.nil?
            if element.displayed? && element.text == text
              duration = ((Time.now - start_time) * 1000).round(2)
              log_element_action('FOUND', "element with #{args.join(', ')}", duration)
              return element
            end
          elsif !visible.nil?
            if element.displayed?
              duration = ((Time.now - start_time) * 1000).round(2)
              log_element_action('FOUND', "element with #{args.join(', ')}", duration)
              return element
            end
          elsif !text.nil?
            if element.text == text
              duration = ((Time.now - start_time) * 1000).round(2)
              log_element_action('FOUND', "element with #{args.join(', ')}", duration)
              return element
            end
          # Just return first element
          else
            duration = ((Time.now - start_time) * 1000).round(2)
            log_element_action('FOUND', "element with #{args.join(', ')}", duration)
            return element
          end
        end
        raise ElementNotFoundError.new(find_args.join(', '), Appom.max_wait_time)
      end
    rescue WaitError => e
      log_error("Element not found", { args: find_args, timeout: Appom.max_wait_time })
      raise ElementNotFoundError.new(find_args.join(', '), Appom.max_wait_time)
    end

    # Find elements
    def _all(*find_args)
      args, text, visible = deduce_element_args(find_args)
      elements = page.find_elements(*args)
      els = []

      elements.each do |element|
        if !visible.nil? && !text.nil?
          if element.displayed? && element.text == text
            els.push(element)
          end
        elsif !visible.nil?
          if element.displayed?
            els.push(element)
          end
        elsif !text.nil?
          if element.text == text
            els.push(element)
          end
        else
          els.push(element)
        end
      end
      return els
    end

    # Check page has or has not element with find_args
    # If page has element return TRUE else return FALSE
    def _check_has_element(*find_args)
      args, text, visible = deduce_element_args(find_args)
      elements = page.find_elements(*args)

      if visible.nil? && text.nil? 
        return elements.empty? ? false : true
      else
        is_found = false
        elements.each do |element|
          if !visible.nil? && !text.nil?
            if element.displayed? && element.text == text
              is_found = true
            end
          elsif !visible.nil?
            if element.displayed?
              is_found = true
            end
          elsif !text.nil?
            if element.text == text
              is_found = true
            end
          end
        end
        return is_found
      end
    end

    ##
    # Use wait to get elements
    # Before timeout we will try to find elements until response return array is not empty
    #
    def wait_until_get_not_empty(*find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until do
        result = page.find_elements(*find_args)
        # If response is empty we will return false to make it not pass Wait condition
        if result.empty?
          raise ElementNotFoundError.new(find_args.join(', '), Appom.max_wait_time)
        end
        # Return result
        return result
      end
    end

    # Function is used to check
    # Note: Function WILL NOT RETURN ELEMENT
    def wait_until(type, *find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until do
        case type
        # Function only return true if element enabled or raise an error if time out
        when 'element enable'
          _find(*find_args).enabled?
        # Function only return true if element disabled or raise an error if time out
        when 'element disable'
          result = _find(*find_args)
          if result.enabled?
            raise StandardError, "Still found an element enable with args = #{find_args}"
          end
          return true
        # Function only return true if we can find at least one element (array is not empty) or raise error
        when 'at least one element exists'
          result = _all(*find_args)
          if result.empty?
            raise ElementNotFoundError.new(find_args.join(', '), Appom.max_wait_time)
          end
          return true

        # Function only return true if we can't find at least one element (array is empty) or raise error
        when 'no element exists'
          result = _all(*find_args)
          if !result.empty?
            message = "Still found #{result.size} element#{'s' if result.size > 1}"
            raise ElementError.new(message, { elements_found: result.size, selector: find_args.join(', ') })
          end
          return true
        end
      end
    end

    private

    def deduce_element_args(args)
      # Flatten argument array first if we are in case array inside array
      args = args.flatten

      if args.empty?
        raise InvalidElementError, 'You should provide search arguments in element creation'
      end

      # Get last key and check if it contain 'text' key
      text = nil
      visible = nil

      args.each do |arg|
        if arg.is_a?(Hash)
          # Extract text value
          if arg.key?(:text)
            text = arg[:text]
            args.delete(arg)
          end
          # Extract visible value
          if arg.key?(:visible)
            visible = arg[:visible]
            args.delete(arg)
          end
        end
      end
      [args, text, visible]
    end
  end
end