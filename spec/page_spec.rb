require 'spec_helper'

RSpec.describe Appom::Page do
  let(:mock_driver) { double('appium_driver') }
  let(:page) { Class.new(Appom::Page).new }

  before do
    Appom.driver = mock_driver
  end

  describe '#page' do
    it 'returns the Appom driver when no instance page is set' do
      expect(page.page).to eq(mock_driver)
    end
  end

  describe 'element definition' do
    let(:test_page_class) do
      Class.new(Appom::Page) do
        element :login_button, :accessibility_id, 'login_btn'
        elements :menu_items, :class, 'menu_item'
      end
    end

    let(:test_page) { test_page_class.new }
    let(:mock_element) { double('element') }

    before do
      allow(mock_driver).to receive(:find_elements).and_return([mock_element])
    end

    it 'defines element methods' do
      expect(test_page).to respond_to(:login_button)
      expect(test_page).to respond_to(:menu_items)
    end

    it 'defines helper methods for elements' do
      expect(test_page).to respond_to(:has_login_button)
      expect(test_page).to respond_to(:has_no_login_button)
      expect(test_page).to respond_to(:login_button_enable)
      expect(test_page).to respond_to(:login_button_disable)
      expect(test_page).to respond_to(:login_button_params)
    end

    it 'stores element parameters' do
      params = test_page.login_button_params
      expect(params).to include(:accessibility_id, 'login_btn')
    end
  end

  describe 'section definition' do
    let(:test_section_class) do
      Class.new(Appom::Section) do
        element :title, :id, 'section_title'
      end
    end

    let(:test_section_class) do
      Class.new(Appom::Section) do
        element :nav_link, :class, 'nav-link'
      end
    end

    let(:test_page_class) do
      section_class = test_section_class
      Class.new(Appom::Page) do
        section :header, section_class, :id, 'header_section'
      end
    end

    let(:test_page) { test_page_class.new }
    let(:mock_section_element) { double('section_element') }

    before do
      allow(mock_driver).to receive(:find_elements).and_return([mock_section_element])
    end

    it 'defines section methods' do
      expect(test_page).to respond_to(:header)
    end

    it 'returns section instance when called' do
      section = test_page.header
      expect(section).to be_a(test_section_class)
      expect(section.root_element).to eq(mock_section_element)
    end
  end
end