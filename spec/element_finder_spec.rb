# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Appom::ElementFinder do
  let(:test_class) do
    Class.new do
      include Appom::ElementFinder

      attr_accessor :driver

      def page
        @driver || Appom.driver
      end

      def initialize(driver = nil)
        @driver = driver
      end
    end
  end

  let(:finder_instance) { test_class.new(mock_driver) }
  let(:mock_driver) { double('appium_driver') }
  let(:mock_element) { double('element', displayed?: true, enabled?: true, text: 'Test Text') }
  let(:mock_elements) { [mock_element, mock_element] }

  before do
    allow(mock_driver).to receive(:find_element).and_return(mock_element)
    allow(mock_driver).to receive(:find_elements).and_return(mock_elements)
    allow(Appom).to receive(:max_wait_time).and_return(5)
    allow(finder_instance).to receive(:log_debug)
    allow(finder_instance).to receive(:log_element_action)
    allow(finder_instance).to receive(:log_error)
    Appom.driver = mock_driver
  end

  describe '.included' do
    context 'when caching is enabled' do
      it 'includes cache-aware finder' do
        allow(Appom).to receive(:cache_config).and_return(enabled: true)

        expect do
          Class.new { include Appom::ElementFinder }
        end.not_to raise_error
      end
    end

    context 'when caching fails to load' do
      it 'continues without caching' do
        allow(Appom).to receive(:cache_config).and_raise(StandardError)

        expect do
          Class.new { include Appom::ElementFinder }
        end.not_to raise_error
      end
    end
  end

  describe '#_find' do
    context 'with basic locator strategy' do
      it 'finds element successfully' do
        result = finder_instance._find(:id, 'test_id')

        expect(result).to eq(mock_element)
        expect(mock_driver).to have_received(:find_elements).with(:id, 'test_id')
      end

      it 'logs the finding process' do
        finder_instance._find(:id, 'test_id')

        expect(finder_instance).to have_received(:log_debug).with(
          'Finding element',
          { args: [:id, 'test_id'], text: nil, visible: nil },
        )
        expect(finder_instance).to have_received(:log_element_action).with(
          'FOUND',
          'element with id, test_id',
          kind_of(Numeric),
        )
      end
    end

    context 'with text option' do
      it 'finds element with matching text' do
        allow(mock_element).to receive(:text).and_return('Matching Text')

        result = finder_instance._find(:id, 'test_id', text: 'Matching Text')

        expect(result).to eq(mock_element)
      end

      it 'skips element with non-matching text' do
        non_matching_element = double('element', displayed?: true, enabled?: true, text: 'Wrong Text')
        matching_element = double('element', displayed?: true, enabled?: true, text: 'Correct Text')
        allow(mock_driver).to receive(:find_elements).and_return([non_matching_element, matching_element])

        result = finder_instance._find(:id, 'test_id', text: 'Correct Text')

        expect(result).to eq(matching_element)
      end
    end

    context 'with visible option' do
      it 'finds visible element' do
        allow(mock_element).to receive(:displayed?).and_return(true)

        result = finder_instance._find(:id, 'test_id', visible: true)

        expect(result).to eq(mock_element)
        expect(mock_element).to have_received(:displayed?)
      end

      it 'skips invisible element' do
        invisible_element = double('element', displayed?: false, enabled?: true, text: 'Text')
        visible_element = double('element', displayed?: true, enabled?: true, text: 'Text')
        allow(mock_driver).to receive(:find_elements).and_return([invisible_element, visible_element])

        result = finder_instance._find(:id, 'test_id', visible: true)

        expect(result).to eq(visible_element)
      end
    end

    context 'with both text and visible options' do
      it 'finds element matching both conditions' do
        allow(mock_element).to receive_messages(displayed?: true, text: 'Test Text')

        result = finder_instance._find(:id, 'test_id', text: 'Test Text', visible: true)

        expect(result).to eq(mock_element)
        expect(mock_element).to have_received(:displayed?)
        expect(mock_element).to have_received(:text)
      end
    end

    context 'when element is not found' do
      it 'raises ElementNotFoundError after timeout' do
        allow(mock_driver).to receive(:find_elements).and_return([])
        allow(Appom::Wait).to receive(:new).and_return(double('wait').tap do |wait|
          allow(wait).to receive(:until).and_raise(Appom::WaitError)
        end)

        expect do
          finder_instance._find(:id, 'missing_id')
        end.to raise_error(Appom::ElementNotFoundError)

        expect(finder_instance).to have_received(:log_error).with(
          'Element not found',
          { args: [:id, 'missing_id'], timeout: 5 },
        )
      end
    end

    context 'with flattened arguments' do
      it 'handles nested array arguments' do
        result = finder_instance._find([[:id, 'test_id']])

        expect(result).to eq(mock_element)
        expect(mock_driver).to have_received(:find_elements).with(:id, 'test_id')
      end
    end
  end

  describe '#_all' do
    it 'returns all found elements' do
      result = finder_instance._all(:class_name, 'test_class')

      expect(result).to eq(mock_elements)
      expect(mock_driver).to have_received(:find_elements).with(:class_name, 'test_class')
    end

    context 'with text filter' do
      it 'returns only elements with matching text' do
        element_with_text = double('element', text: 'Match')
        element_without_text = double('element', text: 'No Match')
        allow(mock_driver).to receive(:find_elements).and_return([element_with_text, element_without_text])

        result = finder_instance._all(:class_name, 'test_class', text: 'Match')

        expect(result).to eq([element_with_text])
      end
    end

    context 'with visible filter' do
      it 'returns only visible elements' do
        visible_element = double('element', displayed?: true)
        invisible_element = double('element', displayed?: false)
        allow(mock_driver).to receive(:find_elements).and_return([visible_element, invisible_element])

        result = finder_instance._all(:class_name, 'test_class', visible: true)

        expect(result).to eq([visible_element])
      end
    end

    context 'with both text and visible filters' do
      it 'returns elements matching both conditions' do
        matching_element = double('element', displayed?: true, text: 'Test')
        invisible_element = double('element', displayed?: false, text: 'Test')
        wrong_text_element = double('element', displayed?: true, text: 'Wrong')
        elements = [matching_element, invisible_element, wrong_text_element]
        allow(mock_driver).to receive(:find_elements).and_return(elements)

        result = finder_instance._all(:class_name, 'test_class', text: 'Test', visible: true)

        expect(result).to eq([matching_element])
      end
    end

    context 'when no elements match filters' do
      it 'returns empty array' do
        invisible_element = double('element', displayed?: false)
        allow(mock_driver).to receive(:find_elements).and_return([invisible_element])

        result = finder_instance._all(:class_name, 'test_class', visible: true)

        expect(result).to eq([])
      end
    end
  end

  describe '#_check_has_element' do
    context 'without filters' do
      it 'returns true when elements exist' do
        result = finder_instance._check_has_element(:id, 'test_id')

        expect(result).to be true
      end

      it 'returns false when no elements exist' do
        allow(mock_driver).to receive(:find_elements).and_return([])

        result = finder_instance._check_has_element(:id, 'missing_id')

        expect(result).to be false
      end
    end

    context 'with visible filter' do
      it 'returns true when visible element exists' do
        allow(mock_element).to receive(:displayed?).and_return(true)

        result = finder_instance._check_has_element(:id, 'test_id', visible: true)

        expect(result).to be true
      end

      it 'returns false when only invisible elements exist' do
        allow(mock_element).to receive(:displayed?).and_return(false)

        result = finder_instance._check_has_element(:id, 'test_id', visible: true)

        expect(result).to be false
      end
    end

    context 'with text filter' do
      it 'returns true when element with text exists' do
        allow(mock_element).to receive(:text).and_return('Expected Text')

        result = finder_instance._check_has_element(:id, 'test_id', text: 'Expected Text')

        expect(result).to be true
      end

      it 'returns false when no element has matching text' do
        allow(mock_element).to receive(:text).and_return('Different Text')

        result = finder_instance._check_has_element(:id, 'test_id', text: 'Expected Text')

        expect(result).to be false
      end
    end
  end

  describe '#wait_until_get_not_empty' do
    context 'when elements are found' do
      it 'returns the elements' do
        result = finder_instance.wait_until_get_not_empty(:class_name, 'test_class')

        expect(result).to eq(mock_elements)
      end
    end

    context 'when elements are not found' do
      it 'raises ElementNotFoundError' do
        allow(mock_driver).to receive(:find_elements).and_return([])

        expect do
          finder_instance.wait_until_get_not_empty(:id, 'missing_id')
        end.to raise_error(Appom::ElementNotFoundError)
      end
    end

    it 'uses Wait with max_wait_time' do
      wait_instance = double('wait')
      allow(Appom::Wait).to receive(:new).with(timeout: 5).and_return(wait_instance)
      allow(wait_instance).to receive(:until).and_yield.and_return(mock_elements)

      finder_instance.wait_until_get_not_empty(:id, 'test_id')

      expect(Appom::Wait).to have_received(:new).with(timeout: 5)
      expect(wait_instance).to have_received(:until)
    end
  end

  describe '#wait_until' do
    let(:wait_instance) { double('wait') }

    before do
      allow(Appom::Wait).to receive(:new).and_return(wait_instance)
      allow(wait_instance).to receive(:until).and_yield.and_return(true)
    end

    context 'with element enable type' do
      it 'waits until element is enabled' do
        allow(mock_element).to receive(:enabled?).and_return(true)

        result = finder_instance.wait_until('element enable', :id, 'test_id')

        expect(result).to be true
        expect(mock_element).to have_received(:enabled?)
      end
    end

    context 'with element disable type' do
      it 'waits until element is disabled' do
        allow(mock_element).to receive(:enabled?).and_return(false)

        result = finder_instance.wait_until('element disable', :id, 'test_id')

        expect(result).to be true
      end

      it 'raises error if element remains enabled' do
        allow(mock_element).to receive(:enabled?).and_return(true)

        expect do
          finder_instance.wait_until('element disable', :id, 'test_id')
        end.to raise_error(StandardError, /Still found an element enable/)
      end
    end

    context 'with at least one element exists type' do
      it 'returns true when elements exist' do
        result = finder_instance.wait_until('at least one element exists', :class_name, 'test_class')

        expect(result).to be true
      end

      it 'raises ElementNotFoundError when no elements exist' do
        allow(finder_instance).to receive(:_all).and_return([])

        expect do
          finder_instance.wait_until('at least one element exists', :id, 'missing_id')
        end.to raise_error(Appom::ElementNotFoundError)
      end
    end

    context 'with no element exists type' do
      it 'returns true when no elements exist' do
        allow(finder_instance).to receive(:_all).and_return([])

        result = finder_instance.wait_until('no element exists', :id, 'missing_id')

        expect(result).to be true
      end

      it 'raises ElementError when elements still exist' do
        allow(finder_instance).to receive(:_all).and_return(mock_elements)

        expect do
          finder_instance.wait_until('no element exists', :id, 'test_id')
        end.to raise_error(Appom::ElementError, /Still found 2 elements/)
      end

      it 'raises ElementError with proper message for single element' do
        single_element = [mock_element]
        allow(finder_instance).to receive(:_all).and_return(single_element)

        expect do
          finder_instance.wait_until('no element exists', :id, 'test_id')
        end.to raise_error(Appom::ElementError, /Still found 1 element/)
      end
    end
  end

  describe '#deduce_element_args' do
    context 'with empty args' do
      it 'raises InvalidElementError' do
        expect do
          finder_instance.send(:deduce_element_args, [])
        end.to raise_error(Appom::InvalidElementError, 'You should provide search arguments in element creation')
      end
    end

    context 'with text option' do
      it 'extracts text value and removes from args' do
        args, text, visible = finder_instance.send(:deduce_element_args, [:id, 'test', { text: 'Sample Text' }])

        expect(args).to eq([:id, 'test'])
        expect(text).to eq('Sample Text')
        expect(visible).to be_nil
      end
    end

    context 'with visible option' do
      it 'extracts visible value and removes from args' do
        args, text, visible = finder_instance.send(:deduce_element_args, [:id, 'test', { visible: true }])

        expect(args).to eq([:id, 'test'])
        expect(text).to be_nil
        expect(visible).to be true
      end
    end

    context 'with both text and visible options' do
      it 'extracts both values' do
        args, text, visible = finder_instance.send(:deduce_element_args, [
                                                     :id, 'test', { text: 'Text', visible: false },
                                                   ],)

        expect(args).to eq([:id, 'test'])
        expect(text).to eq('Text')
        expect(visible).to be false
      end
    end

    context 'with flattened nested arrays' do
      it 'flattens the arguments' do
        args, text, visible = finder_instance.send(:deduce_element_args, [[:id, 'test'], { text: 'Text' }])

        expect(args).to eq([:id, 'test'])
        expect(text).to eq('Text')
        expect(visible).to be_nil
      end
    end

    context 'without options' do
      it 'returns args as-is with nil text and visible' do
        args, text, visible = finder_instance.send(:deduce_element_args, [:xpath, '//button'])

        expect(args).to eq([:xpath, '//button'])
        expect(text).to be_nil
        expect(visible).to be_nil
      end
    end
  end
end
