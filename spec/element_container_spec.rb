# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Appom::ElementContainer do
  let(:test_page_class) do
    Class.new do
      include Appom::ElementContainer
      include Appom::ElementFinder

      attr_reader :driver

      def initialize(driver = nil)
        @driver = driver
      end

      def page
        @driver || Appom.driver
      end

      # Mock methods that would be provided by ElementFinder
      def _find(*args)
        @driver.find_element(*args)
      end

      def _all(*args)
        @driver.find_elements(*args)
      end

      def wait_until_get_not_empty(*args)
        elements = @driver.find_elements(*args)
        raise Appom::ElementNotFoundError.new(args.join(', '), 5) if elements.empty?

        elements
      end

      def wait_until(type, *args)
        case type
        when 'at least one element exists'
          !@driver.find_elements(*args).empty?
        when 'no element exists'
          @driver.find_elements(*args).empty?
        when 'element enable'
          @driver.find_element(*args).enabled?
        when 'element disable'
          !@driver.find_element(*args).enabled?
        end
      end
    end
  end

  let(:test_section_class) do
    Class.new(Appom::Section) do
      def self.default_search_arguments
        [:class_name, 'section']
      end
    end
  end

  let(:page_instance) { test_page_class.new(mock_driver) }
  let(:mock_driver) { double('appium_driver') }
  let(:mock_element) { double('element', enabled?: true, displayed?: true) }

  before do
    allow(mock_driver).to receive_messages(find_element: mock_element, find_elements: [mock_element, mock_element])
    Appom.driver = mock_driver
  end

  describe '.included' do
    it 'extends the class with ClassMethods' do
      expect(test_page_class).to respond_to(:element)
      expect(test_page_class).to respond_to(:elements)
      expect(test_page_class).to respond_to(:section)
      expect(test_page_class).to respond_to(:sections)
    end
  end

  describe '#raise_if_block' do
    it 'raises UnsupportedBlockError when block is given' do
      expect do
        page_instance.raise_if_block(page_instance, 'test_element', true, :element)
      end.to raise_error(Appom::UnsupportedBlockError, /#<Class:.*>#element#test_element does not accept blocks/)
    end

    it 'does not raise when no block is given' do
      expect do
        page_instance.raise_if_block(page_instance, 'test_element', false, :element)
      end.not_to raise_error
    end
  end

  describe '#merge_args' do
    it 'merges find_args and runtime_args' do
      find_args = [:id, 'test_id']
      runtime_args = { timeout: 10 }

      result = page_instance.merge_args(find_args, runtime_args)

      expect(result).to eq([:id, 'test_id', [:timeout, 10]])
    end

    it 'flattens nested arrays' do
      find_args = [[:id, 'test_id'], [:class, 'test']]
      runtime_args = {}

      result = page_instance.merge_args(find_args, runtime_args)

      expect(result).to eq([:id, 'test_id', :class, 'test'])
    end

    it 'handles empty runtime_args' do
      find_args = [:xpath, '//button']

      result = page_instance.merge_args(find_args)

      expect(result).to eq([:xpath, '//button'])
    end

    it 'duplicates input arrays to avoid mutation' do
      find_args = [:id, 'test_id']
      runtime_args = { text: 'test' }

      page_instance.merge_args(find_args, runtime_args)

      expect(find_args).to eq([:id, 'test_id'])
      expect(runtime_args).to eq({ text: 'test' })
    end
  end

  describe 'ClassMethods' do
    describe '#element' do
      before do
        allow(Appom::ElementValidation).to receive(:validate_element_args)
        test_page_class.element(:login_button, :id, 'login_btn')
      end

      it 'validates element arguments' do
        expect(Appom::ElementValidation).to have_received(:validate_element_args).with(:login_button, :id, 'login_btn')
      end

      it 'creates element method' do
        expect(page_instance).to respond_to(:login_button)
      end

      it 'element method returns found element' do
        result = page_instance.login_button
        expect(result).to eq(mock_element)
        expect(mock_driver).to have_received(:find_element).with(:id, 'login_btn')
      end

      it 'element method accepts runtime args' do
        page_instance.login_button(timeout: 15)
        expect(mock_driver).to have_received(:find_element).with(:id, 'login_btn', { timeout: 15 })
      end

      it 'raises error when block is given' do
        expect do
          page_instance.login_button { 'block content' }
        end.to raise_error(Appom::UnsupportedBlockError, /#<Class:.*>#element#login_button does not accept blocks/)
      end

      it 'creates helper methods' do
        expect(page_instance).to respond_to(:has_login_button)
        expect(page_instance).to respond_to(:has_no_login_button)
        expect(page_instance).to respond_to(:login_button_enable)
        expect(page_instance).to respond_to(:login_button_disable)
        expect(page_instance).to respond_to(:login_button_params)
      end

      it 'adds element to mapped_items' do
        expect(test_page_class.mapped_items).to include(:login_button)
      end

      context 'with empty find_args' do
        it 'creates error method' do
          test_page_class.element(:empty_element)

          expect do
            page_instance.empty_element
          end.to raise_error(Appom::InvalidElementError, "Element 'empty_element' was defined without proper selector arguments")
        end
      end
    end

    describe '#elements' do
      before do
        allow(Appom::ElementValidation).to receive(:validate_element_args)
        test_page_class.elements(:menu_items, :class_name, 'menu_item')
      end

      it 'validates element arguments' do
        expect(Appom::ElementValidation).to have_received(:validate_element_args).with(:menu_items, :class_name, 'menu_item')
      end

      it 'creates elements method' do
        expect(page_instance).to respond_to(:menu_items)
      end

      it 'elements method returns found elements' do
        result = page_instance.menu_items
        expect(result).to eq([mock_element, mock_element])
        expect(mock_driver).to have_received(:find_elements).with(:class_name, 'menu_item')
      end

      it 'raises error when block is given' do
        expect do
          page_instance.menu_items { 'block content' }
        end.to raise_error(Appom::UnsupportedBlockError, /#<Class:.*>#elements#menu_items does not accept blocks/)
      end

      it 'creates helper methods including get_all' do
        expect(page_instance).to respond_to(:has_menu_items)
        expect(page_instance).to respond_to(:has_no_menu_items)
        expect(page_instance).to respond_to(:get_all_menu_items)
        expect(page_instance).to respond_to(:menu_items_params)
      end
    end

    describe '#section' do
      before do
        allow(Appom::ElementValidation).to receive(:validate_section_args)
      end

      context 'with section class provided' do
        it 'creates section method with provided class' do
          test_page_class.section(:header, test_section_class, :id, 'header')

          expect(page_instance).to respond_to(:header)

          result = page_instance.header
          expect(result).to be_a(test_section_class)
        end
      end

      context 'with block provided' do
        it 'creates anonymous section class from block' do
          test_page_class.section(:footer, :id, 'footer') do
            element :link, :tag_name, 'a'
          end

          result = page_instance.footer
          expect(result).to be_a(Appom::Section)
          expect(result.class.mapped_items).to include(:link)
        end
      end

      context 'with default search arguments' do
        it 'uses section class default search arguments' do
          test_page_class.section(:sidebar, test_section_class)

          result = page_instance.sidebar
          expect(result).to be_a(test_section_class)
          expect(mock_driver).to have_received(:find_element).with(:class_name, 'section')
        end
      end

      it 'validates section arguments' do
        test_page_class.section(:content, test_section_class, :id, 'content')
        expect(Appom::ElementValidation).to have_received(:validate_section_args).with(:content, test_section_class, :id, 'content')
      end

      it 'creates helper methods' do
        test_page_class.section(:nav, test_section_class, :id, 'nav')

        expect(page_instance).to respond_to(:has_nav)
        expect(page_instance).to respond_to(:has_no_nav)
        expect(page_instance).to respond_to(:nav_enable)
        expect(page_instance).to respond_to(:nav_disable)
        expect(page_instance).to respond_to(:nav_params)
      end
    end

    describe '#sections' do
      before do
        allow(Appom::ElementValidation).to receive(:validate_section_args)
        test_page_class.sections(:cards, test_section_class, :class_name, 'card')
      end

      it 'creates sections method' do
        expect(page_instance).to respond_to(:cards)
      end

      it 'returns array of section instances' do
        result = page_instance.cards
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first).to be_a(test_section_class)
      end

      it 'raises error when block is given' do
        expect do
          page_instance.cards { 'block content' }
        end.to raise_error(Appom::UnsupportedBlockError, /#<Class:.*>#sections#cards does not accept blocks/)
      end

      it 'creates helper methods including get_all' do
        expect(page_instance).to respond_to(:has_cards)
        expect(page_instance).to respond_to(:has_no_cards)
        expect(page_instance).to respond_to(:get_all_cards)
        expect(page_instance).to respond_to(:cards_params)
      end
    end

    describe '#add_to_mapped_items' do
      it 'initializes mapped_items array' do
        new_class = Class.new { include Appom::ElementContainer }
        new_class.add_to_mapped_items(:test_item)

        expect(new_class.mapped_items).to eq([:test_item])
      end

      it 'adds items to existing mapped_items' do
        test_page_class.add_to_mapped_items(:item1)
        test_page_class.add_to_mapped_items(:item2)

        expect(test_page_class.mapped_items).to include(:item1, :item2)
      end
    end

    describe 'helper method creation' do
      before do
        allow(Appom::ElementValidation).to receive(:validate_element_args)
        test_page_class.element(:submit_btn, :id, 'submit')
      end

      describe 'existence checker' do
        it 'has_element method works' do
          allow(page_instance).to receive(:wait_until).with('at least one element exists', :id, 'submit').and_return(true)

          result = page_instance.has_submit_btn
          expect(result).to be true
        end
      end

      describe 'non-existence checker' do
        it 'has_no_element method works' do
          allow(page_instance).to receive(:wait_until).with('no element exists', :id, 'submit').and_return(true)

          result = page_instance.has_no_submit_btn
          expect(result).to be true
        end
      end

      describe 'enable checker' do
        it 'element_enable method works' do
          allow(page_instance).to receive(:wait_until).with('element enable', :id, 'submit').and_return(true)

          result = page_instance.submit_btn_enable
          expect(result).to be true
        end
      end

      describe 'disable checker' do
        it 'element_disable method works' do
          allow(page_instance).to receive(:wait_until).with('element disable', :id, 'submit').and_return(true)

          result = page_instance.submit_btn_disable
          expect(result).to be true
        end
      end

      describe 'params getter' do
        it 'element_params method returns merged args' do
          result = page_instance.submit_btn_params
          expect(result).to eq([:id, 'submit'])
        end
      end

      describe 'get_all_elements method' do
        before do
          test_page_class.elements(:list_items, :class_name, 'item')
        end

        it 'waits until elements are found' do
          allow(page_instance).to receive(:wait_until_get_not_empty).with(:class_name, 'item').and_return([mock_element, mock_element])

          result = page_instance.get_all_list_items
          expect(result).to eq([mock_element, mock_element])
        end
      end

      describe 'get_all_sections method' do
        before do
          test_page_class.sections(:panels, test_section_class, :class_name, 'panel')
        end

        it 'waits until sections are found and returns section instances' do
          allow(page_instance).to receive(:wait_until_get_not_empty).with(:class_name, 'panel').and_return([mock_element, mock_element])

          result = page_instance.get_all_panels
          expect(result).to be_an(Array)
          expect(result.length).to eq(2)
          expect(result.first).to be_a(test_section_class)
        end
      end
    end

    describe 'error handling for empty find_args' do
      context 'when no find args provided to element' do
        it 'creates error method' do
          test_page_class.element(:broken_element)

          expect do
            page_instance.broken_element
          end.to raise_error(Appom::InvalidElementError, "Element 'broken_element' was defined without proper selector arguments")
        end
      end

      context 'when no find args provided to helper methods' do
        before do
          # Simulate element with empty args
          allow(test_page_class).to receive(:create_helper_method) do |name, *args, &block|
            if args.empty?
              test_page_class.define_method(name) { raise Appom::InvalidElementError, name.to_s }
            else
              block.call
            end
          end
        end

        it 'creates error methods for helpers' do
          test_page_class.send(:create_existence_checker, 'test')

          expect do
            page_instance.has_test
          end.to raise_error(Appom::InvalidElementError)
        end
      end
    end

    describe 'section class extraction and validation' do
      describe '#extract_section_options' do
        it 'extracts class from first argument' do
          args = [test_section_class, :id, 'section']
          section_class, find_args = test_page_class.send(:extract_section_options, args)

          expect(section_class).to eq(test_section_class)
          expect(find_args).to eq([:id, 'section'])
        end

        it 'handles block-based section creation' do
          section_class, find_args = test_page_class.send(:extract_section_options, [:id, 'test']) do
            element :title, :tag_name, 'h1'
          end

          expect(section_class.ancestors).to include(Appom::Section)
          expect(find_args).to eq([:id, 'test'])
        end
      end

      describe '#deduce_section_class' do
        it 'returns provided base class when no block given' do
          result = test_page_class.send(:deduce_section_class, test_section_class)
          expect(result).to eq(test_section_class)
        end

        it 'creates new class from block' do
          result = test_page_class.send(:deduce_section_class, test_section_class) do
            element :custom, :id, 'custom'
          end

          expect(result.ancestors).to include(test_section_class)
          expect(result.mapped_items).to include(:custom)
        end

        it 'raises error when no class or block provided' do
          expect do
            test_page_class.send(:deduce_section_class, nil)
          end.to raise_error(Appom::InvalidSectionError, 'Invalid section definition: You should provide descendant of Appom::Section class or/and a block as the second argument.')
        end
      end

      describe '#deduce_search_arguments' do
        it 'uses provided arguments' do
          result = test_page_class.send(:deduce_search_arguments, test_section_class, [:id, 'test'])
          expect(result).to eq([:id, 'test'])
        end

        it 'falls back to section class default arguments' do
          result = test_page_class.send(:deduce_search_arguments, test_section_class, [])
          expect(result).to eq([:class_name, 'section'])
        end

        it 'raises error when no arguments available' do
          section_without_defaults = Class.new(Appom::Section)

          expect do
            test_page_class.send(:deduce_search_arguments, section_without_defaults, [])
          end.to raise_error(Appom::InvalidSectionError, 'Invalid section definition: You should provide search arguments in section creation or set_default_search_arguments within section class')
        end
      end
    end
  end
end
