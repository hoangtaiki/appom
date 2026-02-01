# frozen_string_literal: true

require 'spec_helper'

# Import exception constants for tests
ElementNotFoundError = Appom::ElementNotFoundError
WaitError = Appom::WaitError

# Test class including the Helpers module for testing
# Disable RuboCop Metrics/BlockLength for this test class
RSpec.describe Appom::Helpers do
  let(:test_class) do
    Class.new do
      include Appom::Helpers
      include Appom::ElementFinder

      attr_accessor :driver, :mock_element

      def initialize(driver = nil)
        @driver = driver
      end

      # Define methods that tests expect to call
      def test_element
        @mock_element
      end

      def has_test_element # rubocop:disable Naming/PredicateMethod --- IGNORE ---
        true # Default, can be overridden in tests
      end

      def has_no_test_element # rubocop:disable Naming/PredicateMethod --- IGNORE ---
        true # Default, can be overridden in tests
      end

      def scroll(direction = :down)
        # Mock implementation
      end

      def test_element_params
        %i[id test_element]
      end

      def test_elements_params
        %i[id test_elements]
      end

      def has_element1?
        false  # Default, can be overridden in tests
      end

      def has_element2?
        false  # Default, can be overridden in tests
      end

      def element1_params
        [:id, 'element1']
      end

      def element2_params
        [:id, 'element2']
      end
    end
  end

  let(:helper_instance) { test_class.new }
  let(:mock_element) { double('element', tap: nil, text: 'Test Text', enabled?: true, attribute: 'test_value') }
  let(:mock_driver) { double('driver') }

  before do
    helper_instance.mock_element = mock_element
    helper_instance.driver = mock_driver
    allow(Appom).to receive(:max_wait_time).and_return(10)
    allow(helper_instance).to receive(:log_warn)
    allow(helper_instance).to receive(:log_info)
    allow(helper_instance).to receive(:log_debug)
    allow(helper_instance).to receive(:log_error)

    # Mock Performance module
    stub_const('Performance', double('Performance'))
    allow(Performance).to receive(:time_operation).and_yield
  end

  describe 'ElementHelpers' do
    describe '#tap_and_wait' do
      it 'taps element and waits for it to be enabled' do
        result = helper_instance.tap_and_wait(:test_element, timeout: 5)

        expect(result).to eq(mock_element)
        expect(mock_element).to have_received(:tap)
        expect(Performance).to have_received(:time_operation).with('tap_and_wait_test_element')
      end

      it 'uses default timeout when not specified' do
        allow(helper_instance).to receive(:test_element_enable)

        helper_instance.tap_and_wait(:test_element)

        expect(mock_element).to have_received(:tap)
      end

      it 'calls enable checker if method exists' do
        allow(helper_instance).to receive(:respond_to?).with(:test_element_enable).and_return(true)
        allow(helper_instance).to receive(:test_element_enable)

        helper_instance.tap_and_wait(:test_element)

        expect(helper_instance).to have_received(:test_element_enable)
      end
    end

    describe '#get_text_with_retry' do
      it 'returns element text on first try' do
        result = helper_instance.get_text_with_retry(:test_element)

        expect(result).to eq('Test Text')
        expect(mock_element).to have_received(:text)
      end

      it 'retries on failure' do
        call_count = 0
        allow(mock_element).to receive(:text) do
          call_count += 1
          raise StandardError, 'Element not ready' if call_count < 3

          'Success Text'
        end

        result = helper_instance.get_text_with_retry(:test_element, retries: 3)

        expect(result).to eq('Success Text')
        expect(mock_element).to have_received(:text).exactly(3).times
      end

      it 'raises error after max retries' do
        allow(mock_element).to receive(:text).and_raise(StandardError, 'Persistent error')

        expect do
          helper_instance.get_text_with_retry(:test_element, retries: 2)
        end.to raise_error(StandardError, 'Persistent error')
      end

      it 'sleeps between retries' do
        allow(mock_element).to receive(:text).and_raise(StandardError, 'Error')
        allow(helper_instance).to receive(:sleep)

        expect do
          helper_instance.get_text_with_retry(:test_element, retries: 2)
        end.to raise_error(StandardError)

        expect(helper_instance).to have_received(:sleep).with(0.5).twice
      end
    end

    describe '#wait_and_tap' do
      it 'waits for element and taps it' do
        allow(helper_instance).to receive(:respond_to?).with('has_test_element').and_return(true)
        # Use spy to track has_test_element
        allow(helper_instance).to receive(:has_test_element).and_return(true)
        # Make the test class method available and spy on it
        allow(helper_instance.class).to receive(:method_defined?).with(:has_test_element).and_return(true)

        helper_instance.wait_and_tap(:test_element)

        expect(helper_instance).to have_received(:has_test_element)
        expect(mock_element).to have_received(:tap)
        expect(Performance).to have_received(:time_operation).with('wait_and_tap_test_element')
      end

      it 'skips wait check if method does not exist' do
        allow(helper_instance).to receive(:respond_to?).with('has_test_element').and_return(false)

        helper_instance.wait_and_tap(:test_element)

        expect(mock_element).to have_received(:tap)
      end
    end

    describe '#get_attribute_with_fallback' do
      it 'returns element attribute value' do
        result = helper_instance.get_attribute_with_fallback(:test_element, :value)

        expect(result).to eq('test_value')
        expect(mock_element).to have_received(:attribute).with(:value)
      end

      it 'returns fallback value when attribute is nil' do
        allow(mock_element).to receive(:attribute).and_return(nil)

        result = helper_instance.get_attribute_with_fallback(:test_element, :value, 'fallback')

        expect(result).to eq('fallback')
      end

      it 'returns fallback value on error' do
        allow(mock_element).to receive(:attribute).and_raise(StandardError, 'Attribute error')

        result = helper_instance.get_attribute_with_fallback(:test_element, :value, 'fallback')

        expect(result).to eq('fallback')
        expect(helper_instance).to have_received(:log_warn).with(/Failed to get attribute/)
      end

      it 'uses nil as default fallback' do
        allow(mock_element).to receive(:attribute).and_raise(StandardError, 'Error')

        result = helper_instance.get_attribute_with_fallback(:test_element, :value)

        expect(result).to be_nil
      end
    end

    describe '#element_contains_text?' do
      it 'returns true when element contains text' do
        allow(helper_instance).to receive(:get_text_with_retry).and_return('This is Test Text here')

        result = helper_instance.element_contains_text?(:test_element, 'Test')

        expect(result).to be true
      end

      it 'returns false when element does not contain text' do
        allow(helper_instance).to receive(:get_text_with_retry).and_return('Different Text')

        result = helper_instance.element_contains_text?(:test_element, 'NotFound')

        expect(result).to be false
      end

      it 'returns false when element text is nil' do
        allow(helper_instance).to receive(:get_text_with_retry).and_return(nil)

        result = helper_instance.element_contains_text?(:test_element, 'Any')

        expect(result).to be false
      end
    end

    describe '#scroll_to_and_tap' do
      it 'taps element if already visible' do
        allow(helper_instance).to receive(:respond_to?).with('has_test_element').and_return(true)
        allow(helper_instance).to receive_messages(has_test_element: true, wait_and_tap: mock_element)
        # Spy on :scroll so we can assert it was not called
        allow(helper_instance).to receive(:scroll)

        result = helper_instance.scroll_to_and_tap(:test_element)

        expect(result).to eq(mock_element)
        expect(helper_instance).to have_received(:wait_and_tap).with(:test_element)
        expect(helper_instance).not_to have_received(:scroll)
      end

      it 'scrolls and searches for element' do
        call_count = 0
        allow(helper_instance).to receive(:respond_to?).with('has_test_element').and_return(true)
        allow(helper_instance).to receive(:has_test_element) do
          call_count += 1
          call_count > 2
        end
        allow(helper_instance).to receive(:scroll)
        allow(helper_instance).to receive(:wait_and_tap).and_return(mock_element)

        result = helper_instance.scroll_to_and_tap(:test_element)

        expect(result).to eq(mock_element)
        expect(helper_instance).to have_received(:scroll).with(:down).twice
      end

      it 'uses custom scroll direction' do
        allow(helper_instance).to receive(:respond_to?).with('has_test_element').and_return(true)
        allow(helper_instance).to receive(:has_test_element).and_return(false, true)
        allow(helper_instance).to receive_messages(scroll: nil, wait_and_tap: mock_element)

        helper_instance.scroll_to_and_tap(:test_element, direction: :up)

        expect(helper_instance).to have_received(:scroll).with(:up)
      end

      it 'raises error after max scrolls' do
        allow(helper_instance).to receive(:respond_to?).with('has_test_element').and_return(true)
        allow(helper_instance).to receive_messages(has_test_element: false, scroll: nil)

        expect do
          helper_instance.scroll_to_and_tap(:test_element)
        end.to raise_error(Appom::ElementNotFoundError, /after 5 scrolls/)

        expect(helper_instance).to have_received(:scroll).exactly(5).times
      end
    end
  end

  describe 'WaitHelpers' do
    before do
      allow(Appom::SmartWait).to receive_messages(
        until_clickable: mock_element,
        until_text_matches: mock_element,
        until_invisible: mock_element,
        until_count_equals: [mock_element],
        until_condition: mock_element,
      )
    end

    describe '#wait_for_clickable' do
      it 'waits for element to be clickable' do
        result = helper_instance.wait_for_clickable(:test_element)

        expect(result).to eq(mock_element)
        expect(Appom::SmartWait).to have_received(:until_clickable).with(:id, :test_element, timeout: 10)
      end

      it 'uses custom timeout' do
        helper_instance.wait_for_clickable(:test_element, timeout: 20)

        expect(Appom::SmartWait).to have_received(:until_clickable).with(:id, :test_element, timeout: 20)
      end
    end

    describe '#wait_for_text_match' do
      it 'waits for text to match' do
        result = helper_instance.wait_for_text_match(:test_element, 'Expected', exact: true)

        expect(result).to eq(mock_element)
        expect(Appom::SmartWait).to have_received(:until_text_matches).with(
          :id, :test_element, text: 'Expected', exact: true, timeout: 10,
        )
      end

      it 'uses default exact: false' do
        helper_instance.wait_for_text_match(:test_element, 'Text')

        expect(Appom::SmartWait).to have_received(:until_text_matches).with(
          :id, :test_element, text: 'Text', exact: false, timeout: 10,
        )
      end
    end

    describe '#wait_for_invisible' do
      it 'waits for element to be invisible' do
        result = helper_instance.wait_for_invisible(:test_element)

        expect(result).to eq(mock_element)
        expect(Appom::SmartWait).to have_received(:until_invisible).with(:id, :test_element, timeout: 10)
      end
    end

    describe '#wait_for_count' do
      it 'waits for specific element count' do
        result = helper_instance.wait_for_count(:test_elements, 3)

        expect(result).to eq([mock_element])
        expect(Appom::SmartWait).to have_received(:until_count_equals).with(:id, :test_elements, count: 3, timeout: 10)
      end
    end

    describe '#wait_for_condition' do
      it 'waits for custom condition' do
        condition = -> { true }

        result = helper_instance.wait_for_condition(:test_element, description: 'custom', &condition)

        expect(result).to eq(mock_element)
        expect(Appom::SmartWait).to have_received(:until_condition).with(
          :id, :test_element, timeout: 10, description: 'custom',
        )
      end

      it 'uses default description' do
        helper_instance.wait_for_condition(:test_element) { true }

        expect(Appom::SmartWait).to have_received(:until_condition).with(
          :id, :test_element, timeout: 10, description: 'custom condition',
        )
      end
    end

    describe '#wait_for_any' do
      let(:wait_instance) { double('wait') }

      before do
        allow(Appom::Wait).to receive(:new).and_return(wait_instance)
      end

      it 'waits for any element to appear' do
        call_count = 0
        allow(helper_instance).to receive(:has_element1) do
          call_count += 1
          call_count > 1
        end
        allow(helper_instance).to receive_messages(respond_to?: true, has_element2: false)
        allow(wait_instance).to receive(:until).and_yield.and_return(:element1)

        result = helper_instance.wait_for_any(:element1, :element2)

        expect(result).to eq(:element1)
      end

      it 'raises ElementNotFoundError when no element appears' do
        allow(helper_instance).to receive_messages(respond_to?: true, has_element1: false, has_element2: false)
        allow(wait_instance).to receive(:until).and_raise(Appom::WaitError)

        expect do
          helper_instance.wait_for_any(:element1, :element2, timeout: 5)
        end.to raise_error(Appom::ElementNotFoundError, /any of: element1, element2/)
      end
    end

    describe '#wait_for_disappear' do
      it 'uses has_no_method when available' do
        allow(helper_instance).to receive(:respond_to?).with('has_no_test_element').and_return(true)
        allow(helper_instance).to receive(:has_no_test_element).and_return(true)

        result = helper_instance.wait_for_disappear(:test_element)

        expect(helper_instance).to have_received(:has_no_test_element)
        expect(result).to be true
      end

      it 'uses wait and element finding when has_no_method not available' do
        allow(helper_instance).to receive(:respond_to?).with('has_no_test_element').and_return(false)
        wait_instance = double('wait')
        allow(Appom::Wait).to receive(:new).and_return(wait_instance)
        allow(wait_instance).to receive(:until).and_return(true)

        result = helper_instance.wait_for_disappear(:test_element)

        expect(result).to be true
      end
    end

    describe '#wait_for_text_in_element' do
      let(:wait_instance) { double('wait') }

      before do
        allow(Appom::Wait).to receive(:new).and_return(wait_instance)
      end

      it 'waits for text to appear in element' do
        allow(wait_instance).to receive(:until).and_yield.and_return(true)
        allow(helper_instance).to receive(:get_text_with_retry).and_return('Expected text here')

        result = helper_instance.wait_for_text_in_element(:test_element, 'Expected')

        expect(result).to be true
        expect(helper_instance).to have_received(:get_text_with_retry).with(:test_element, retries: 1)
      end

      it 'handles nil element text' do
        allow(wait_instance).to receive(:until).and_return(true)
        allow(helper_instance).to receive(:get_text_with_retry).and_return(nil)

        result = helper_instance.wait_for_text_in_element(:test_element, 'Expected')

        expect(result).to be true
      end

      it 'handles exceptions during text retrieval' do
        allow(wait_instance).to receive(:until).and_return(true)
        allow(helper_instance).to receive(:get_text_with_retry).and_raise(StandardError)

        result = helper_instance.wait_for_text_in_element(:test_element, 'Expected')

        expect(result).to be true
      end
    end
  end

  describe 'DebugHelpers' do
    before do
      stub_const('Screenshot', double('Screenshot'))
      allow(Screenshot).to receive_messages(
        capture: 'screenshot.png',
        capture_before_after: 'action_screenshot.png',
        capture_sequence: 'sequence.png',
        capture_on_failure: 'failure_screenshot.png',
      )
    end

    describe '#take_debug_screenshot' do
      it 'takes screenshot with default prefix' do
        result = helper_instance.take_debug_screenshot

        expect(result).to eq('screenshot.png')
        expect(Screenshot).to have_received(:capture).with('debug')
      end

      it 'uses custom prefix' do
        helper_instance.take_debug_screenshot('custom')

        expect(Screenshot).to have_received(:capture).with('custom')
      end
    end

    describe '#take_element_screenshot' do
      it 'takes screenshot of specific element' do
        result = helper_instance.take_element_screenshot(:test_element)

        expect(result).to eq('screenshot.png')
        expect(Screenshot).to have_received(:capture).with('element_test_element', element: mock_element)
      end

      it 'uses custom prefix' do
        helper_instance.take_element_screenshot(:test_element, 'custom')

        expect(Screenshot).to have_received(:capture).with('custom_test_element', element: mock_element)
      end

      it 'handles screenshot errors gracefully' do
        allow(Screenshot).to receive(:capture).and_raise(StandardError, 'Screenshot failed')

        result = helper_instance.take_element_screenshot(:test_element)

        expect(result).to be_nil
        expect(helper_instance).to have_received(:log_error).with(/Failed to take element screenshot/)
      end
    end

    describe '#screenshot_action' do
      it 'takes before/after screenshots' do
        result = helper_instance.screenshot_action('test_action') { 'action_result' }

        expect(result).to eq('action_screenshot.png')
        expect(Screenshot).to have_received(:capture_before_after).with('test_action')
      end
    end

    describe '#screenshot_sequence' do
      it 'takes screenshot sequence with default options' do
        result = helper_instance.screenshot_sequence('sequence') { 'sequence_result' }

        expect(result).to eq('sequence.png')
        expect(Screenshot).to have_received(:capture_sequence).with(
          'sequence', interval: 1.0, max_duration: 10.0,
        )
      end

      it 'uses custom options' do
        helper_instance.screenshot_sequence('custom', interval: 0.5, max_duration: 5.0) { 'result' }

        expect(Screenshot).to have_received(:capture_sequence).with(
          'custom', interval: 0.5, max_duration: 5.0,
        )
      end
    end

    describe '#screenshot_failure' do
      it 'takes failure screenshot without exception' do
        result = helper_instance.screenshot_failure('test_failure')

        expect(result).to eq('failure_screenshot.png')
        expect(Screenshot).to have_received(:capture_on_failure).with('test_failure', nil)
      end

      it 'takes failure screenshot with exception' do
        exception = StandardError.new('Test error')

        helper_instance.screenshot_failure('test_failure', exception)

        expect(Screenshot).to have_received(:capture_on_failure).with('test_failure', exception)
      end
    end

    describe '#dump_page_source' do
      it 'saves page source successfully' do
        mock_driver = double('driver', page_source: '<html><body>Test</body></html>')
        allow(helper_instance).to receive(:driver).and_return(mock_driver)
        allow(helper_instance).to receive(:respond_to?).with(:driver).and_return(true)
        allow(File).to receive(:write)
        mock_time = double('time')
        allow(mock_time).to receive(:strftime).and_return('20240131_120000')
        allow(Time).to receive(:now).and_return(mock_time)

        result = helper_instance.dump_page_source('test')

        expect(result).to eq('test_20240131_120000.xml')
        expect(File).to have_received(:write).with(
          'test_20240131_120000.xml',
          '<html><body>Test</body></html>',
        )
        expect(helper_instance).to have_received(:log_info).with(/Page source saved/)
      end

      it 'handles missing driver gracefully' do
        allow(helper_instance).to receive(:respond_to?).with(:driver).and_return(false)

        result = helper_instance.dump_page_source

        expect(result).to be_nil
      end

      it 'handles nil driver gracefully' do
        allow(helper_instance).to receive(:respond_to?).with(:driver).and_return(true)
        allow(helper_instance).to receive(:driver).and_return(nil)

        result = helper_instance.dump_page_source

        expect(result).to be_nil
      end

      it 'handles file write errors' do
        mock_driver = double('driver', page_source: '<html></html>')
        allow(helper_instance).to receive(:driver).and_return(mock_driver)
        allow(helper_instance).to receive(:respond_to?).with(:driver).and_return(true)
        allow(File).to receive(:write).and_raise(StandardError, 'Write failed')

        result = helper_instance.dump_page_source

        expect(result).to be_nil
        expect(helper_instance).to have_received(:log_error).with(/Failed to save page source/)
      end
    end

    describe '#debug_elements_info' do
      let(:button_element) do
        double('element1',
               tag_name: 'button',
               text: 'Click me',
               displayed?: true,
               enabled?: true,
               location: { x: 10, y: 20 },
               size: { width: 100, height: 30 },)
      end

      let(:input_element) do
        double('element2',
               tag_name: 'input',
               text: '',
               displayed?: false,
               enabled?: false,
               location: { x: 50, y: 100 },
               size: { width: 200, height: 40 },)
      end

      before do
        allow(helper_instance).to receive(:_all).and_return([button_element, input_element])
      end

      it 'returns information about all matching elements' do
        result = helper_instance.debug_elements_info(:class_name, 'test')

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)

        first_info = result[0]
        expect(first_info[:index]).to eq(0)
        expect(first_info[:tag_name]).to eq('button')
        expect(first_info[:text]).to eq('Click me')
        expect(first_info[:displayed]).to be true
        expect(first_info[:enabled]).to be true

        second_info = result[1]
        expect(second_info[:index]).to eq(1)
        expect(second_info[:tag_name]).to eq('input')
        expect(second_info[:text]).to eq('')
        expect(second_info[:displayed]).to be false
      end

      it 'logs element information' do
        helper_instance.debug_elements_info(:class_name, 'test')

        expect(helper_instance).to have_received(:log_info).with(/Found 2 elements/)
        expect(helper_instance).to have_received(:log_debug).at_least(2).times
      end

      it 'handles element errors gracefully' do
        failing_element = double('failing_element')
        allow(failing_element).to receive(:tag_name).and_raise(StandardError, 'Element error')
        allow(helper_instance).to receive(:_all).and_return([failing_element])

        result = helper_instance.debug_elements_info(:id, 'test')

        expect(result.first[:error]).to eq('Element error')
      end

      it 'handles _all method errors' do
        allow(helper_instance).to receive(:_all).and_raise(StandardError, 'Find error')

        result = helper_instance.debug_elements_info(:id, 'test')

        expect(result).to eq([])
        expect(helper_instance).to have_received(:log_error).with(/Failed to get elements info/)
      end
    end
  end

  describe 'PerformanceHelpers' do
    describe '#time_element_operation' do
      it 'times element operation' do
        result = helper_instance.time_element_operation(:test_element, :tap) { 'operation_result' }

        expect(result).to eq('operation_result')
        expect(Performance).to have_received(:time_operation).with('test_element_tap')
      end
    end

    describe '#element_performance_stats' do
      before do
        allow(Performance).to receive_messages(stats: {
                                                 'test_element_tap' => { duration: 0.1 },
                                                 'other_element_click' => { duration: 0.2 },
                                                 'test_element_scroll' => { duration: 0.15 },
                                               }, summary: { total_operations: 10 },)
      end

      it 'returns stats for specific element' do
        result = helper_instance.element_performance_stats(:test_element)

        expected = {
          'test_element_tap' => { duration: 0.1 },
          'test_element_scroll' => { duration: 0.15 },
        }
        expect(result).to eq(expected)
      end

      it 'returns summary when no element specified' do
        result = helper_instance.element_performance_stats

        expect(result).to eq({ total_operations: 10 })
        expect(Performance).to have_received(:summary)
      end
    end
  end

  describe 'VisualHelpers' do
    before do
      stub_const('Visual', double('Visual'))
      test_helpers = double('test_helpers')
      allow(Visual).to receive(:test_helpers).and_return(test_helpers)
      allow(Visual).to receive(:regression_test)
      allow(test_helpers).to receive(:highlight_element)
      allow(test_helpers).to receive(:wait_for_visual_stability)
    end

    describe '#screenshot_with_highlight' do
      it 'highlights element and takes screenshot' do
        helper_instance.screenshot_with_highlight(:test_element, filename: 'test.png')

        expect(Visual.test_helpers).to have_received(:highlight_element).with(mock_element)
      end
    end

    describe '#visual_regression_test' do
      it 'performs visual regression test' do
        options = { threshold: 0.1 }

        helper_instance.visual_regression_test('test_name', options)

        expect(Visual).to have_received(:regression_test).with('test_name', options)
      end
    end

    describe '#wait_for_visual_stability' do
      it 'waits for visual stability with element' do
        options = { timeout: 5 }

        helper_instance.wait_for_visual_stability(:test_element, **options)

        expect(Visual.test_helpers).to have_received(:wait_for_visual_stability).with(
          element: mock_element,
          **options,
        )
      end

      it 'waits for visual stability without element' do
        options = { timeout: 10 }

        helper_instance.wait_for_visual_stability(nil, **options)

        expect(Visual.test_helpers).to have_received(:wait_for_visual_stability).with(
          element: nil,
          **options,
        )
      end
    end
  end

  describe 'ElementStateHelpers' do
    before do
      stub_const('ElementState', double('ElementState'))
      allow(ElementState).to receive(:track_element)
      allow(ElementState).to receive(:wait_for_state_change)
      allow(ElementState).to receive(:element_state)
    end

    describe '#track_element_state' do
      it 'tracks element state with context' do
        context = { test: true }

        helper_instance.track_element_state(:test_element, context: context)

        expect(ElementState).to have_received(:track_element).with(
          mock_element,
          name: 'test_element',
          context: context,
        )
      end
    end

    describe '#wait_for_element_state_change' do
      it 'waits for element state change' do
        expected_changes = { enabled: true }
        options = { timeout: 15 }

        helper_instance.wait_for_element_state_change(:test_element, expected_changes: expected_changes, **options)

        expect(ElementState).to have_received(:wait_for_state_change).with(
          'test_element',
          expected_changes: expected_changes,
          **options,
        )
      end
    end

    describe '#element_current_state' do
      it 'gets current element state' do
        allow(ElementState).to receive(:element_state).and_return({ enabled: true, visible: false })

        result = helper_instance.element_current_state(:test_element)

        expect(result).to eq({ enabled: true, visible: false })
        expect(ElementState).to have_received(:element_state).with('test_element')
      end
    end
  end

  describe 'module inclusion' do
    it 'includes all helper modules when Helpers is included' do
      expect(helper_instance).to respond_to(:tap_and_wait) # ElementHelpers
      expect(helper_instance).to respond_to(:wait_for_clickable) # WaitHelpers
      expect(helper_instance).to respond_to(:take_debug_screenshot) # DebugHelpers
      expect(helper_instance).to respond_to(:time_element_operation) # PerformanceHelpers
      expect(helper_instance).to respond_to(:visual_regression_test) # VisualHelpers
      expect(helper_instance).to respond_to(:track_element_state) # ElementStateHelpers
      # Logging is included via Appom::Logging
    end
  end
end
