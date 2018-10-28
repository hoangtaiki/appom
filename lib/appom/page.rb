module Appom
  class Page
    include Appium
    include ElementContainer

    # Find an element
    def find(*find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until { Appom.driver.find_element(*find_args) }
    end

    # Find elements
    def all(*find_args)
      Appom.driver.find_elements(*find_args)
    end

    ##
    # Use wait to check element non-exist
    # Before timeout we will try to find elements and check response is empty
    #
    def wait_check_util_empty(*find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until do
        Appom.driver.find_elements(*find_args).empty?
      end
    end

    ##
    # Use wait to check element exist
    # Before timeout we will try to find elements and check response is not empty
    #
    def wait_check_util_not_empty(*find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until do
        !Appom.driver.find_elements(*find_args).empty?
      end
    end

    ##
    # Use wait to get elements
    # Before timeout we will try to find elements until response is not empty
    #
    def wait_util_get_not_empty(*find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until do
        result = Appom.driver.find_elements(*find_args)
        # If reponse is empty we will return false to make it not pass Wait condition
        if result.empty?
          return false
        end
        # Return result
        return result
      end
    end

    ##
    # Wait until an element will be enable
    #
    def wait_util_element_enabled(*find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until { Appom.driver.find_element(*find_args).enabled? }
    end

    ##
    # Wait until an element will be disable
    #
    def wait_util_element_disabled(*find_args)
      wait = Wait.new(timeout: Appom.max_wait_time)
      wait.until { !Appom.driver.find_element(*find_args).enabled? }
    end
  end
end