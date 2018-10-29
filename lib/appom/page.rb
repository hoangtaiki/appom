module Appom
  class Page
    include Appium
    include ElementContainer
    include ElementFinder

    def page
      @page || Appom.driver
    end
  end
end