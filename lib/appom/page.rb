module Appom
  class Page
    include Appium
    include ElementContainer

    # Find an element
    def find(*find_args)
      Appom.driver.find_element(*find_args)
    end

    # Find elements
    def all(*find_args)
      Appom.driver.find_elements(*find_args)
    end
  end
end
