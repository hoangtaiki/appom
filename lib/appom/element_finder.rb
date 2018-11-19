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
    # Use wait to check element non-exist
    # Before timeout we will try to find elements and check response is empty
    #
    def wait_check_until_empty(*find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until do
        page.find_elements(*find_args).empty?
      end
    end

    ##
    # Use wait to check element exist
    # Before timeout we will try to find elements and check response is not empty
    #
    def wait_check_until_not_empty(*find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until do
        !page.find_elements(*find_args).empty?
      end
    end

    ##
    # Use wait to get elements
    # Before timeout we will try to find elements until response is not empty
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

    ##
    # Wait until an element will be enable
    #
    def wait_until_element_enabled(*find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until { page.find_element(*find_args).enabled? }
    end

    ##
    # Wait until an element will be disable
    #
    def wait_until_element_disabled(*find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until { !page.find_element(*find_args).enabled? }
    end
  end
end