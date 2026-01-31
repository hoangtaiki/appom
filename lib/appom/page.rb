require 'appom/helpers'

module Appom
  class Page
    include Appium
    include ElementContainer
    include ElementFinder
    include Helpers

    def initialize(driver = nil)
      @page = driver
    end

    def page
      @page || Appom.driver
    end
  end
end