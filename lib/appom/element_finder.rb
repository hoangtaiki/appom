# frozen_string_literal: true

# Element finding functionality for Appom automation framework
# Handles element location with various strategies and options
module Appom::ElementFinder
  include Appom::Logging

  def self.included(klass)
    # Include cache-aware finder if caching is enabled

    klass.include(ElementCache::CacheAwareFinder) if Appom.cache_config[:enabled]
  rescue StandardError
    # Continue without caching if it fails to load
  end

  # Find an element
  def _find(*find_args) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    args, text, visible = deduce_element_args(find_args)
    wait = Appom::Wait.new(timeout: Appom.max_wait_time)

    log_debug('Finding element', { args: args, text: text, visible: visible })
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
      raise Appom::ElementNotFoundError.new(find_args.join(', '), Appom.max_wait_time)
    end
  rescue Appom::WaitError
    log_error('Element not found', { args: find_args, timeout: Appom.max_wait_time })
    raise Appom::ElementNotFoundError.new(find_args.join(', '), Appom.max_wait_time)
  end

  # Find elements
  def _all(*find_args) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    args, text, visible = deduce_element_args(find_args)
    elements = page.find_elements(*args)
    els = []

    elements.each do |element|
      if !visible.nil? && !text.nil?
        els.push(element) if element.displayed? && element.text == text
      elsif !visible.nil?
        els.push(element) if element.displayed?
      elsif !text.nil?
        els.push(element) if element.text == text
      else
        els.push(element)
      end
    end
    els
  end

  # Check page has or has not element with find_args
  # If page has element return TRUE else return FALSE
  def _check_has_element(*find_args) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    args, text, visible = deduce_element_args(find_args)
    elements = page.find_elements(*args)

    return !elements.empty? if visible.nil? && text.nil?

    is_found = false
    elements.each do |element|
      if !visible.nil? && !text.nil?
        is_found = true if element.displayed? && element.text == text
      elsif !visible.nil?
        is_found = true if element.displayed?
      elsif !text.nil?
        is_found = true if element.text == text
      end
    end
    is_found
  end

  ##
  # Use wait to get elements
  # Before timeout we will try to find elements until response return array is not empty
  #
  def wait_until_get_not_empty(*find_args)
    wait = Appom::Wait.new(timeout: Appom.max_wait_time)
    wait.until do
      result = page.find_elements(*find_args)
      # If response is empty we will return false to make it not pass Wait condition
      raise Appom::ElementNotFoundError.new(find_args.join(', '), Appom.max_wait_time) if result.empty?

      # Return result
      return result
    end
  end

  # Function is used to check
  # Note: Function WILL NOT RETURN ELEMENT
  def wait_until(type, *find_args) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    wait = Appom::Wait.new(timeout: Appom.max_wait_time)
    wait.until do
      case type
      # Function only return true if element enabled or raise an error if time out
      when 'element enable'
        _find(*find_args).enabled?
      # Function only return true if element disabled or raise an error if time out
      when 'element disable'
        result = _find(*find_args)
        raise StandardError, "Still found an element enable with args = #{find_args}" if result.enabled?

        return true
      # Function only return true if we can find at least one element (array is not empty) or raise error
      when 'at least one element exists'
        result = _all(*find_args)
        raise Appom::ElementNotFoundError.new(find_args.join(', '), Appom.max_wait_time) if result.empty?

        return true

      # Function only return true if we can't find at least one element (array is empty) or raise error
      when 'no element exists'
        result = _all(*find_args)
        unless result.empty?
          message = "Still found #{result.size} element#{'s' if result.size > 1}"
          raise Appom::ElementError.new(message, { elements_found: result.size, selector: find_args.join(', ') })
        end
        return true
      end
    end
  end

  private

  def deduce_element_args(args)
    # Flatten argument array first if we are in case array inside array
    args = args.flatten

    raise Appom::InvalidElementError.new if args.empty?

    # Get last key and check if it contain 'text' key
    text = nil
    visible = nil

    args.each do |arg|
      next unless arg.is_a?(Hash)

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
    [args, text, visible]
  end
end
