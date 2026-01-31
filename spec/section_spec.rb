# Helper to allow double inside class definitions
def test_double(*, **)
  RSpec::Mocks::Double.new(*, **)
end
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Appom::Section do
  let(:mock_parent) { double('parent_page') }
  let(:mock_root_element) { double('root_element') }
  let(:section) { described_class.new(mock_parent, mock_root_element) }

  describe '#initialize' do
    it 'sets parent and root_element' do
      expect(section.parent).to eq(mock_parent)
      expect(section.root_element).to eq(mock_root_element)
    end
  end

  describe '#page' do
    context 'when root_element is present' do
      it 'returns root_element' do
        expect(section.page).to eq(mock_root_element)
      end
    end

    context 'when root_element is nil' do
      let(:section_with_nil_root) { described_class.new(mock_parent, nil) }

      it 'calls super' do
        # When root_element is nil, page method should delegate to parent
        expect(section_with_nil_root.page).to eq(mock_parent)
      end
    end
  end

  describe '#parent_page' do
    context 'when parent is directly a Page' do
      let(:mock_page) { double('page') }

      before do
        allow(mock_page).to receive(:is_a?).with(Appom::Page).and_return(true)
      end

      it 'returns the parent' do
        section_with_page_parent = described_class.new(mock_page, mock_root_element)
        expect(section_with_page_parent.parent_page).to eq(mock_page)
      end
    end

    context 'when parent is nested sections' do
      let(:mock_grandparent_page) { double('grandparent_page') }
      let(:mock_parent_section) { double('parent_section') }

      before do
        allow(mock_parent_section).to receive(:is_a?).with(Appom::Page).and_return(false)
        allow(mock_parent_section).to receive(:parent).and_return(mock_grandparent_page)
        allow(mock_grandparent_page).to receive(:is_a?).with(Appom::Page).and_return(true)
      end

      it 'traverses up to find the page' do
        section_with_nested_parent = described_class.new(mock_parent_section, mock_root_element)
        expect(section_with_nested_parent.parent_page).to eq(mock_grandparent_page)
      end
    end

    context 'with deeply nested sections' do
      let(:mock_page) { double('page') }
      let(:mock_section1) { double('section1') }
      let(:mock_section2) { double('section2') }
      let(:mock_section3) { double('section3') }

      before do
        # Set up the chain: section3 -> section2 -> section1 -> page
        allow(mock_section3).to receive(:is_a?).with(Appom::Page).and_return(false)
        allow(mock_section3).to receive(:parent).and_return(mock_section2)

        allow(mock_section2).to receive(:is_a?).with(Appom::Page).and_return(false)
        allow(mock_section2).to receive(:parent).and_return(mock_section1)

        allow(mock_section1).to receive(:is_a?).with(Appom::Page).and_return(false)
        allow(mock_section1).to receive(:parent).and_return(mock_page)

        allow(mock_page).to receive(:is_a?).with(Appom::Page).and_return(true)
      end

      it 'traverses through multiple levels to find the page' do
        deeply_nested_section = described_class.new(mock_section3, mock_root_element)
        expect(deeply_nested_section.parent_page).to eq(mock_page)
      end
    end
  end

  describe 'included modules' do
    it 'includes Appium module' do
      expect(described_class.included_modules).to include(Appium)
    end

    it 'includes ElementContainer' do
      expect(described_class.included_modules).to include(Appom::ElementContainer)
    end

    it 'includes ElementFinder' do
      expect(described_class.included_modules).to include(Appom::ElementFinder)
    end

    it 'includes Helpers' do
      expect(described_class.included_modules).to include(Appom::Helpers)
    end
  end

  describe 'element definition capabilities' do
    let(:test_section_class) do
      Class.new(Appom::Section) do
        element :title, :tag_name, 'h1'
        elements :links, :tag_name, 'a'

        def _find(*_args)
          # Mock implementation
          double('element')
        end

        def _all(*_args)
          # Mock implementation
          [double('element')]
        end
      end
    end

    let(:section_instance) { test_section_class.new(mock_parent, mock_root_element) }

    it 'can define elements' do
      expect(section_instance).to respond_to(:title)
      expect(section_instance).to respond_to(:links)
    end

    it 'inherits mapped_items from ElementContainer' do
      expect(test_section_class.mapped_items).to include(:title, :links)
    end

    it 'creates helper methods for elements' do
      expect(section_instance).to respond_to(:has_title)
      expect(section_instance).to respond_to(:has_no_title)
      expect(section_instance).to respond_to(:title_params)
    end
  end

  describe 'nested sections' do
    let(:inner_section_class) do
      Class.new(Appom::Section) do
        element :inner_element, :id, 'inner'

        def _find(*_args)
          double('inner_element')
        end
      end
    end

    let(:outer_section_class) do
      inner_class = inner_section_class
      Class.new(Appom::Section) do
        element :outer_element, :id, 'outer'
        section :inner, inner_class, :class_name, 'inner'

        def _find(*_args)
          test_double('outer_element')
        end
      end
    end

    let(:outer_section) { outer_section_class.new(mock_parent, mock_root_element) }

    it 'supports nested sections' do
      expect(outer_section).to respond_to(:inner)

      inner = outer_section.inner
      expect(inner).to be_a(inner_section_class)
      expect(inner.parent).to eq(outer_section)
    end

    it 'nested sections can access their parent page' do
      allow(mock_parent).to receive(:is_a?).with(Appom::Page).and_return(true)

      inner = outer_section.inner
      expect(inner.parent_page).to eq(mock_parent)
    end
  end

  describe 'inheritance and customization' do
    let(:custom_section_class) do
      Class.new(Appom::Section) do
        element :custom_button, :id, 'custom_btn'

        def custom_action
          'custom action performed'
        end

        def _find(*_args)
          double('custom_element', tap: nil)
        end
      end
    end

    let(:custom_section) { custom_section_class.new(mock_parent, mock_root_element) }

    it 'allows custom methods' do
      expect(custom_section.custom_action).to eq('custom action performed')
    end

    it 'inherits all base section functionality' do
      expect(custom_section.parent).to eq(mock_parent)
      expect(custom_section.root_element).to eq(mock_root_element)
      expect(custom_section.page).to eq(mock_root_element)
    end

    it 'can define custom elements' do
      expect(custom_section).to respond_to(:custom_button)
      expect(custom_section_class.mapped_items).to include(:custom_button)
    end
  end

  describe 'helper modules integration' do
    let(:section_with_helpers) do
      Class.new(Appom::Section) do
        element :test_element, :id, 'test'

        # Mock the required methods for helpers to work
        def _find(*_args)
          double('element', tap: nil, text: 'Test Text', enabled?: true)
        end

        def test_element_params
          [:id, 'test']
        end

        def has_test_element
          true
        end

        def respond_to_missing?(method_name, include_private = false)
          method_name.to_s.start_with?('test_element_') || super
        end

        def method_missing(method_name, *args, &)
          if method_name.to_s.start_with?('test_element_')
            # Mock helper method behavior
            true
          else
            super
          end
        end
      end
    end

    let(:section_instance) { section_with_helpers.new(mock_parent, mock_root_element) }

    it 'includes ElementHelpers methods' do
      expect(section_instance).to respond_to(:tap_and_wait)
      expect(section_instance).to respond_to(:get_text_with_retry)
      expect(section_instance).to respond_to(:wait_and_tap)
    end

    it 'includes WaitHelpers methods' do
      expect(section_instance).to respond_to(:wait_for_clickable)
      expect(section_instance).to respond_to(:wait_for_text_match)
      expect(section_instance).to respond_to(:wait_for_invisible)
    end

    it 'includes DebugHelpers methods' do
      expect(section_instance).to respond_to(:take_debug_screenshot)
      expect(section_instance).to respond_to(:take_element_screenshot)
    end

    it 'includes PerformanceHelpers methods' do
      expect(section_instance).to respond_to(:time_element_operation)
      expect(section_instance).to respond_to(:element_performance_stats)
    end

    it 'includes VisualHelpers methods' do
      expect(section_instance).to respond_to(:screenshot_with_highlight)
      expect(section_instance).to respond_to(:visual_regression_test)
    end

    it 'includes ElementStateHelpers methods' do
      expect(section_instance).to respond_to(:track_element_state)
      expect(section_instance).to respond_to(:wait_for_element_state_change)
    end
  end

  describe 'real-world usage patterns' do
    let(:form_section_class) do
      Class.new(Appom::Section) do
        element :name_field, :id, 'name'
        element :email_field, :id, 'email'
        element :submit_button, :id, 'submit'
        elements :error_messages, :class_name, 'error'

        def fill_form(name:, email:)
          # Mock form filling
          "Filled form with #{name}, #{email}"
        end

        def submit
          # Mock form submission
          'Form submitted'
        end

        # Mock finder methods
        def _find(*args)
          case args[1]
          when 'name' then test_double('name_field', send_keys: nil)
          when 'email' then test_double('email_field', send_keys: nil)
          when 'submit' then test_double('submit_button', tap: nil)
          else test_double('element')
          end
        end

        def _all(*args)
          case args[1]
          when 'error' then [test_double('error_message', text: 'Error')]
          else [test_double('element')]
          end
        end
      end
    end

    let(:form_section) { form_section_class.new(mock_parent, mock_root_element) }

    it 'supports complex form interactions' do
      expect(form_section.fill_form(name: 'John', email: 'john@test.com')).to eq('Filled form with John, john@test.com')
      expect(form_section.submit).to eq('Form submitted')
    end

    it 'provides access to individual form elements' do
      expect(form_section.name_field).to be_a(RSpec::Mocks::Double)
      expect(form_section.email_field).to be_a(RSpec::Mocks::Double)
      expect(form_section.submit_button).to be_a(RSpec::Mocks::Double)
    end

    it 'provides access to collections of elements' do
      errors = form_section.error_messages
      expect(errors).to be_an(Array)
      expect(errors).not_to be_empty
    end
  end
end
