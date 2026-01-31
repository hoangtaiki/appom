# frozen_string_literal: true

require 'appom/helpers'

class Appom::Page
  include Appium
  include Appom::ElementContainer
  include Appom::ElementFinder
  include Appom::Helpers

  def initialize(driver = nil)
    @page = driver
  end

  def page
    @page || Appom.driver
  end
end
