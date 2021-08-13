module Appom
  module ElementFinder
    # Find an element
    def _find(*find_args)
      args, text, visible = deduce_element_args(find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)

      wait.until do
        elements = page.find_elements(*args)
        elements.each do |element|
          if !visible.nil? && !text.nil?
            if element.displayed? && element.text == text
              return element
            end
          elsif !visible.nil?
            if element.displayed?
              return element
            end
          elsif !text.nil?
            if element.text == text
              return element
            end
          # Just return first element
          else
            return element
          end
        end
        raise Appom::ElementsEmptyError, "Can not found element with args = #{find_args}"
      end
    end

    # Find elements
    def _all(*find_args)
      page.find_elements(*find_args)
    end

    # Check page has or has not element with find_args
    # If page has element return TRUE else return FALSE
    def _check_has_element(*find_args)
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
        # If reponse is empty we will return false to make it not pass Wait condition
        if result.empty?
          raise Appom::ElementsEmptyError, "Can not found any elements with args = #{find_args}"
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
          !_find(*find_args).enabled?
        # Function only return true if we can find at leat one element (array is not empty) or raise error
        when 'at least one element exists'
          args, text, visible = deduce_element_args(find_args)
          !page.find_elements(*args).empty?
        # Function only return true if we can't find at leat one element (array is empty) or raise error
        when 'no element exists'
          args, text, visible = deduce_element_args(find_args)
          page.find_elements(*args).empty?
        end
      end
    end

    private

    def deduce_element_args(args)
      # Flatten argument array first if we are in case array inside array
      args = args.flatten

      if args.empty?
        raise(ArgumentError, 'You should provide search arguments in element creation')
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