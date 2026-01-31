# frozen_string_literal: true

require 'appom/helpers'

class Appom::Section
  include Appium
  include Appom::ElementContainer
  include Appom::ElementFinder
  include Appom::Helpers

  attr_reader :root_element, :parent

  def initialize(parent, root_element)
    @parent = parent
    @root_element = root_element
  end

  def page
    root_element || super
  end

  def parent_page
    candidate_page = parent
    candidate_page = candidate_page.parent until candidate_page.is_a?(Appom::Page)
    candidate_page
  end
end
