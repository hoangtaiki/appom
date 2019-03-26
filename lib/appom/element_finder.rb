module Appom
  module ElementFinder
    # Find an element
    def _find(*find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until { page.find_element(*find_args) }
    end

    # Find elements
    def _all(*find_args)
      page.find_elements(*find_args)
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
          raise Appom::ElementsEmptyError, "Array is empty"
        end
        # Return result
        return result
      end
    end

    # Find element with has text match with `text` value
    # If not find element will raise error
    def find_element_has_text(text, *find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until do
        elements = page.find_elements(*find_args)
        is_found = false
        elements.each do |element|
          element_text = element.text
          if element_text == text
            return element
          end
        end

        if !is_found
          raise Appom::ElementsEmptyError, "Not found element with text #{text}"
        end
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
          page.find_element(*find_args).enabled?
        # Function only return true if element disabled or raise an error if time out
        when 'element disable'
          !page.find_element(*find_args).enabled?
        # Function only return true if we can find at leat one element (array is not empty) or raise error
        when 'at least one element exists'
          !page.find_elements(*find_args).empty?
        # Function only return true if we can't find at leat one element (array is empty) or raise error
        when 'no element exists'
          page.find_elements(*find_args).empty?
        end
      end
    end
  end
end