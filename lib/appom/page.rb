# frozen_string_literal: true

require 'appom/helpers'

# Base page class for Appom automation framework
# Provides common functionality for page objects
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
