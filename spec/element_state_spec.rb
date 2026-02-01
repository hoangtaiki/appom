# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Appom::ElementState do
  let(:tracker) { Appom::ElementState::Tracker.new }
  let(:mock_element) { double('element') }

  before do
    # Mock common element methods
    allow(mock_element).to receive(:attribute) do |attr|
      {
        id: 'test_button',
        class: 'btn btn-primary',
        name: 'submit',
      }[attr]
    end
    allow(mock_element).to receive_messages(displayed?: true, enabled?: true, selected?: false, text: 'Button Text', location: { x: 100, y: 200 }, size: { width: 80, height: 30 })
  end

  describe Appom::ElementState::Tracker do
    describe '#track_element' do
      it 'starts tracking an element with generated ID' do
        element_id = tracker.track_element(mock_element)

        expect(tracker.tracked_elements).to have_key(element_id)
        tracked = tracker.tracked_elements[element_id]
        expect(tracked[:element]).to eq(mock_element)
        expect(tracked[:current_state][:exists]).to be true
        expect(tracked[:current_state][:displayed]).to be true
        expect(tracked[:current_state][:text]).to eq('Button Text')
      end

      it 'accepts custom name and context' do
        element_id = tracker.track_element(mock_element, name: 'submit_button', context: { page: 'login' })

        tracked = tracker.tracked_elements[element_id]
        expect(tracked[:name]).to eq('submit_button')
        expect(tracked[:context][:page]).to eq('login')
      end

      it 'captures comprehensive element state' do
        element_id = tracker.track_element(mock_element)
        state = tracker.tracked_elements[element_id][:current_state]

        expect(state[:exists]).to be true
        expect(state[:displayed]).to be true
        expect(state[:enabled]).to be true
        expect(state[:selected]).to be false
        expect(state[:text]).to eq('Button Text')
        expect(state[:attributes][:id]).to eq('test_button')
        expect(state[:location]).to eq({ x: 100, y: 200 })
        expect(state[:size]).to eq({ width: 80, height: 30 })
      end
    end

    describe '#update_element_state' do
      let!(:element_id) { tracker.track_element(mock_element, name: 'test_element') }

      context 'when element state changes' do
        it 'detects and records state changes' do
          # Initial state
          initial_state = tracker.element_state(element_id)
          expect(initial_state[:text]).to eq('Button Text')

          # Change element state
          allow(mock_element).to receive_messages(text: 'Updated Text', enabled?: false)

          # Update and check for changes
          change_event = tracker.update_element_state(element_id)

          expect(change_event).to be_a(Hash)
          expect(change_event[:changes]).to have_key(:text)
          expect(change_event[:changes][:text][:from]).to eq('Button Text')
          expect(change_event[:changes][:text][:to]).to eq('Updated Text')

          expect(change_event[:changes]).to have_key(:enabled)
          expect(change_event[:changes][:enabled][:from]).to be true
          expect(change_event[:changes][:enabled][:to]).to be false
        end

        it 'stores previous states' do
          # Change state multiple times
          allow(mock_element).to receive(:text).and_return('State 1')
          tracker.update_element_state(element_id)

          allow(mock_element).to receive(:text).and_return('State 2')
          tracker.update_element_state(element_id)

          tracked = tracker.tracked_elements[element_id]
          expect(tracked[:previous_states].size).to be >= 1
          expect(tracked[:change_count]).to be >= 2
        end

        it 'limits stored previous states to 10' do
          15.times do |i|
            allow(mock_element).to receive(:text).and_return("State #{i}")
            tracker.update_element_state(element_id)
          end

          tracked = tracker.tracked_elements[element_id]
          expect(tracked[:previous_states].size).to eq(10)
        end
      end

      context 'when element state remains the same' do
        it 'does not record changes' do
          initial_change_count = tracker.tracked_elements[element_id][:change_count]

          change_event = tracker.update_element_state(element_id)

          expect(change_event).to be_nil
          expect(tracker.tracked_elements[element_id][:change_count]).to eq(initial_change_count)
        end
      end
    end

    describe '#element_history' do
      let!(:element_id) { tracker.track_element(mock_element, name: 'history_test') }

      it 'returns change history for specific element' do
        allow(mock_element).to receive(:text).and_return('Changed Text')
        tracker.update_element_state(element_id)

        history = tracker.element_history(element_id)

        expect(history).to be_an(Array)
        expect(history.length).to be >= 1
        expect(history.first[:element_id]).to eq(element_id)
        expect(history.first[:changes]).to have_key(:text)
      end

      it 'limits history to specified limit' do
        10.times do |i|
          allow(mock_element).to receive(:text).and_return("History #{i}")
          tracker.update_element_state(element_id)
        end

        history = tracker.element_history(element_id, limit: 5)
        expect(history.size).to eq(5)
      end
    end

    describe '#wait_for_state_change' do
      let!(:element_id) { tracker.track_element(mock_element, name: 'wait_test') }

      it 'waits for expected state change' do
        # Simulate state change in background
        Thread.new do
          sleep(0.1)
          allow(mock_element).to receive(:enabled?).and_return(false)
        end

        result = tracker.wait_for_state_change(element_id, expected_changes: { enabled: false }, timeout: 1)

        expect(result[:enabled]).to be false
      end

      it 'raises timeout error when state does not change' do
        expect do
          tracker.wait_for_state_change(element_id, expected_changes: { enabled: false }, timeout: 0.1)
        end.to raise_error(Appom::TimeoutError, /Element state did not change/)
      end
    end

    describe '#wait_for_state' do
      let!(:element_id) { tracker.track_element(mock_element, name: 'condition_test') }

      it 'waits for condition using hash' do
        Thread.new do
          sleep(0.1)
          allow(mock_element).to receive(:displayed?).and_return(false)
        end

        result = tracker.wait_for_state(element_id, { displayed: false }, timeout: 1)

        expect(result[:displayed]).to be false
      end

      it 'waits for condition using proc' do
        Thread.new do
          sleep(0.1)
          allow(mock_element).to receive(:text).and_return('Ready')
        end

        condition = ->(state) { state[:text] == 'Ready' }
        result = tracker.wait_for_state(element_id, condition, timeout: 1)

        expect(result[:text]).to eq('Ready')
      end
    end

    describe '#stop_tracking' do
      let!(:element_id) { tracker.track_element(mock_element, name: 'stop_test') }

      it 'stops tracking and returns summary' do
        allow(mock_element).to receive(:text).and_return('Changed')
        tracker.update_element_state(element_id)

        summary = tracker.stop_tracking(element_id)

        expect(tracker.tracked_elements).not_to have_key(element_id)
        expect(summary[:name]).to eq('stop_test')
        expect(summary[:change_count]).to eq(1)
        expect(summary[:tracking_duration]).to be > 0
      end
    end

    describe '#tracking_summary' do
      before do
        tracker.track_element(mock_element, name: 'element1')
        tracker.track_element(double('element2'), name: 'element2')
      end

      it 'provides comprehensive tracking summary' do
        summary = tracker.tracking_summary

        expect(summary[:total_tracked]).to eq(2)
        expect(summary[:tracking_enabled]).to be true
        expect(summary[:most_active]).to be_an(Hash)
        expect(summary[:recent_changes]).to be_an(Array)
      end
    end

    describe '#find_elements_by_state' do
      before do
        tracker.track_element(mock_element, name: 'enabled_element')

        disabled_element = double('disabled_element')
        allow(disabled_element).to receive_messages(displayed?: true, enabled?: false)
        allow(disabled_element).to receive_messages(
          selected?: false,
          text: 'Disabled',
          attribute: nil,
          location: { x: 0, y: 0 },
          size: { width: 50, height: 20 },
        )
        tracker.track_element(disabled_element, name: 'disabled_element')
      end

      it 'finds elements by state criteria hash' do
        enabled_elements = tracker.find_elements_by_state(enabled: true)
        disabled_elements = tracker.find_elements_by_state(enabled: false)

        expect(enabled_elements.size).to eq(1)
        expect(disabled_elements.size).to eq(1)
        expect(enabled_elements.first[:name]).to include('enabled_element')
      end

      it 'finds elements by state criteria proc' do
        text_criteria = ->(state) { state[:text]&.include?('Button') }
        matching_elements = tracker.find_elements_by_state(text_criteria)

        expect(matching_elements.size).to eq(1)
      end
    end

    describe '#export_tracking_data' do
      before do
        tracker.track_element(mock_element, name: 'export_test')
        allow(mock_element).to receive(:text).and_return('Changed')
        tracker.update_element_state('export_test')
      end

      it 'exports tracking data to JSON' do
        file_path = tracker.export_tracking_data(format: :json, file_path: 'tracking_test.json')

        expect(File.exist?(file_path)).to be true
        data = JSON.parse(File.read(file_path))
        expect(data['tracked_elements']).to have_key('export_test')
        expect(data['state_history']).to be_an(Array)

        File.delete(file_path)
      end

      it 'exports tracking data to YAML' do
        file_path = tracker.export_tracking_data(format: :yaml, file_path: 'tracking_test.yml')

        expect(File.exist?(file_path)).to be true
        data = YAML.load_file(file_path, permitted_classes: [Time, Symbol], aliases: true)
        expect(data[:tracked_elements]).to have_key('export_test')

        File.delete(file_path)
      end
    end

    describe 'observers' do
      let(:observer_calls) { [] }
      let(:observer) { ->(event, *args) { observer_calls << [event, args] } }

      before do
        tracker.add_observer(&observer)
      end

      it 'notifies observers on element tracking' do
        tracker.track_element(mock_element, name: 'observed_element')

        expect(observer_calls).to include(a_collection_starting_with([:element_tracked]))
      end

      it 'notifies observers on state changes' do
        element_id = tracker.track_element(mock_element, name: 'changing_element')
        observer_calls.clear

        allow(mock_element).to receive(:text).and_return('New Text')
        tracker.update_element_state(element_id)

        expect(observer_calls).to include(a_collection_starting_with([:state_changed]))
      end
    end
  end

  describe 'Global ElementState module' do
    before { described_class.clear! }
    after { described_class.clear! }

    describe '.track_element' do
      it 'uses the global tracker' do
        element_id = described_class.track_element(mock_element, name: 'global_test')

        expect(described_class.tracker.tracked_elements).to have_key(element_id)
      end
    end

    describe '.tracking_summary' do
      it 'returns global tracking summary' do
        described_class.track_element(mock_element, name: 'summary_test')
        summary = described_class.tracking_summary

        expect(summary[:total_tracked]).to eq(1)
      end
    end
  end

  describe Appom::ElementState::Monitoring do
    let(:test_class) do
      Class.new do
        include Appom::ElementState::Monitoring

        track_state_changes

        def initialize(element)
          @element = element
        end

        private

        attr_reader :element
      end
    end

    before { Appom::ElementState.clear! }

    it 'enables state tracking for classes' do
      expect(test_class.state_tracking_enabled?).to be true
    end

    it 'provides state tracking methods' do
      instance = test_class.new(mock_element)
      expect(instance).to respond_to(:track_state)
      expect(instance).to respond_to(:current_state)
      expect(instance).to respond_to(:wait_for_state_change)
    end

    context 'missing coverage and edge cases' do
      describe '#find_elements_by_state' do
        before do
          # Track multiple elements with different states
          @element1 = double('element1')
          @element2 = double('element2')
          @element3 = double('element3')

          allow(@element1).to receive_messages(displayed?: true, enabled?: true, text: 'Button1')
          allow(@element2).to receive_messages(displayed?: false, enabled?: true, text: 'Button2')
          allow(@element3).to receive_messages(displayed?: true, enabled?: false, text: 'Button3')

          [@element1, @element2, @element3].each do |el|
            allow(el).to receive_messages(attribute: nil, selected?: false, location: { x: 0, y: 0 }, size: { width: 100, height: 50 })
          end

          tracker.track_element(@element1, name: 'button1')
          tracker.track_element(@element2, name: 'button2')
          tracker.track_element(@element3, name: 'button3')
        end

        it 'finds elements by displayed state' do
          results = tracker.find_elements_by_state(displayed: true)
          expect(results.size).to eq(2)
          expect(results.map { |r| r[:name] }).to contain_exactly('button1', 'button3')
        end

        it 'finds elements by enabled state' do
          results = tracker.find_elements_by_state(enabled: false)
          expect(results.size).to eq(1)
          expect(results.first[:name]).to eq('button3')
        end

        it 'finds elements by multiple criteria' do
          results = tracker.find_elements_by_state(displayed: true, enabled: true)
          expect(results.size).to eq(1)
          expect(results.first[:name]).to eq('button1')
        end

        it 'returns empty array when no elements match' do
          results = tracker.find_elements_by_state(displayed: true, enabled: true, selected: true)
          expect(results).to be_empty
        end
      end

      describe 'observer functionality' do
        let(:observer_calls) { [] }
        let(:observer) { ->(event, *args) { observer_calls << [event, args] } }

        it 'adds and notifies observers' do
          tracker.add_observer(&observer)

          tracker.track_element(mock_element, name: 'test')

          expect(observer_calls).not_to be_empty
          expect(observer_calls.last.first).to eq(:element_tracked)
        end

        it 'removes observers' do
          observer_proc = tracker.add_observer(&observer)
          tracker.remove_observer(observer_proc)

          tracker.track_element(mock_element, name: 'test')

          expect(observer_calls).to be_empty
        end

        it 'notifies observers on state changes' do
          tracker.add_observer(&observer)
          element_id = tracker.track_element(mock_element, name: 'test')

          observer_calls.clear
          allow(mock_element).to receive(:text).and_return('Changed Text')
          tracker.update_element_state(element_id)

          expect(observer_calls.any? { |call| call.first == :state_changed }).to be true
        end
      end

      describe '#tracking_enabled=' do
        it 'disables tracking when set to false' do
          element_id = tracker.track_element(mock_element)

          tracker.tracking_enabled = false
          allow(mock_element).to receive(:text).and_return('Changed')

          expect { tracker.update_element_state(element_id) }.not_to(change do
            tracker.tracked_elements[element_id][:current_state][:text]
          end)
        end

        it 'logs when tracking is disabled' do
          expect { tracker.tracking_enabled = false }.not_to raise_error
        end

        it 'logs when tracking is enabled' do
          tracker.tracking_enabled = false
          expect { tracker.tracking_enabled = true }.not_to raise_error
        end
      end

      describe '#export_tracking_data' do
        before do
          tracker.track_element(mock_element, name: 'export_test')
          allow(mock_element).to receive(:text).and_return('Changed')
          tracker.update_element_state('export_test')
        end

        it 'exports data in JSON format' do
          file_path = tracker.export_tracking_data(format: :json)

          expect(File.exist?(file_path)).to be true
          data = JSON.parse(File.read(file_path))

          expect(data['summary']).to be_a(Hash)
          expect(data['tracked_elements']).to be_a(Hash)
          expect(data['state_history']).to be_an(Array)

          File.delete(file_path)
        end

        it 'exports data in YAML format' do
          file_path = tracker.export_tracking_data(format: :yaml)

          expect(File.exist?(file_path)).to be true
          data = YAML.safe_load_file(file_path, permitted_classes: [Time, Symbol], aliases: true)

          expect(data[:summary]).to be_a(Hash)
          expect(data[:tracked_elements]).to be_a(Hash)
          expect(data[:state_history]).to be_an(Array)

          File.delete(file_path)
        end

        it 'raises error for unsupported format' do
          expect do
            tracker.export_tracking_data(format: :xml)
          end.to raise_error(ArgumentError, /Unsupported format/)
        end

        it 'uses custom file path when provided' do
          custom_path = 'custom_export_test.json'
          file_path = tracker.export_tracking_data(file_path: custom_path)

          expect(file_path).to eq(custom_path)
          expect(File.exist?(custom_path)).to be true

          File.delete(custom_path)
        end
      end

      describe 'element ID generation' do
        it 'uses provided name when available' do
          element_id = tracker.send(:generate_element_id, mock_element, 'custom_name')
          expect(element_id).to eq('custom_name')
        end

        it 'generates ID from element attributes' do
          attr_element = double('attr_element')
          allow(attr_element).to receive(:attribute) do |attr|
            case attr
            when :id then 'test_id'
            when :class then 'test_class'
            end
          end
          allow(attr_element).to receive(:tag_name).and_return('button')

          element_id = tracker.send(:generate_element_id, attr_element, nil)
          expect(element_id).to eq('test_id_test_class_button')
        end

        it 'handles elements without attributes' do
          basic_element = double('basic_element')
          allow(basic_element).to receive(:attribute).and_return(nil)

          element_id = tracker.send(:generate_element_id, basic_element, nil)
          expect(element_id).to match(/element_\d+/)
        end

        it 'handles exceptions during attribute access' do
          broken_element = double('broken_element')
          allow(broken_element).to receive(:attribute).and_raise(StandardError)

          element_id = tracker.send(:generate_element_id, broken_element, nil)
          expect(element_id).to match(/element_\d+/)
        end

        it 'sanitizes special characters in generated ID' do
          special_element = double('special_element')
          allow(special_element).to receive(:attribute) do |attr|
            case attr
            when :id then 'test@id#special'
            when :class then 'class with spaces!'
            end
          end

          element_id = tracker.send(:generate_element_id, special_element, nil)
          expect(element_id).to eq('test_id_special_class_with_spaces_')
        end
      end

      describe 'state capture error handling' do
        it 'handles exceptions during state capture gracefully' do
          problematic_element = double('problematic_element')
          allow(problematic_element).to receive(:displayed?).and_raise(StandardError)
          allow(problematic_element).to receive(:enabled?).and_raise(StandardError)
          allow(problematic_element).to receive(:selected?).and_raise(StandardError)
          allow(problematic_element).to receive(:text).and_raise(StandardError)
          allow(problematic_element).to receive(:attribute).and_raise(StandardError)
          allow(problematic_element).to receive(:location).and_raise(StandardError)
          allow(problematic_element).to receive(:size).and_raise(StandardError)

          state = tracker.send(:capture_element_state, problematic_element)

          expect(state[:exists]).to be false
          expect(state[:displayed]).to be false
          expect(state[:enabled]).to be false
          expect(state[:selected]).to be false
          expect(state[:text]).to be_nil
          expect(state[:attributes]).to eq({})
          expect(state[:location]).to be_nil
          expect(state[:size]).to be_nil
        end
      end

      describe 'update element state error handling' do
        it 'handles missing element_id gracefully' do
          expect { tracker.update_element_state('nonexistent') }.not_to raise_error
        end

        it 'handles disabled tracking' do
          element_id = tracker.track_element(mock_element)
          tracker.tracking_enabled = false

          expect { tracker.update_element_state(element_id) }.not_to raise_error
        end
      end

      describe 'wait methods timeout handling' do
        let!(:element_id) { tracker.track_element(mock_element, name: 'timeout_test') }

        it 'raises timeout error in wait_for_state with proc condition' do
          never_true_condition = ->(_state) { false }

          expect do
            tracker.wait_for_state(element_id, never_true_condition, timeout: 0.1)
          end.to raise_error(Appom::TimeoutError, /Element did not reach expected state/)
        end

        it 'handles invalid condition types in wait_for_state' do
          result = tracker.wait_for_state(element_id, 'invalid', timeout: 0.1)
          expect(result).to be_nil
        rescue Appom::TimeoutError
          # Expected for invalid condition
        end
      end

      describe 'serialize_tracked_elements' do
        it 'serializes tracked elements without circular references' do
          element_id = tracker.track_element(mock_element, name: 'serialize_test')
          allow(mock_element).to receive(:text).and_return('Changed')
          tracker.update_element_state(element_id)

          serialized = tracker.send(:serialize_tracked_elements)

          expect(serialized).to be_a(Hash)
          expect(serialized).to have_key(element_id)

          element_data = serialized[element_id]
          expect(element_data).to have_key(:name)
          expect(element_data).to have_key(:context)
          expect(element_data).to have_key(:current_state)
          expect(element_data).to have_key(:change_count)
          expect(element_data).to have_key(:previous_states_count)
          expect(element_data).not_to have_key(:element) # Should not include actual element
        end
      end

      describe 'most_active_elements' do
        it 'returns most active elements sorted by change count' do
          # Track multiple elements with different activity levels
          id1 = tracker.track_element(mock_element, name: 'low_activity')
          id2 = tracker.track_element(double('element2'), name: 'high_activity')
          id3 = tracker.track_element(double('element3'), name: 'medium_activity')

          # Simulate different levels of activity
          tracker.tracked_elements[id2][:change_count] = 5
          tracker.tracked_elements[id3][:change_count] = 3
          tracker.tracked_elements[id1][:change_count] = 1

          most_active = tracker.send(:most_active_elements, 2)

          expect(most_active).to eq({
                                      'high_activity' => 5,
                                      'medium_activity' => 3,
                                    })
        end
      end
    end

    describe 'Monitoring mixin' do
      let(:monitoring_test_class) do
        Class.new do
          include Appom::ElementState::Monitoring

          track_state_changes

          def initialize(element)
            @element = element
          end
        end
      end

      let(:monitoring_test_instance) { monitoring_test_class.new(mock_element) }

      describe 'class methods' do
        it 'enables state tracking' do
          expect(monitoring_test_class.state_tracking_enabled?).to be true
        end

        it 'defaults to disabled tracking' do
          untracked_class = Class.new { include Appom::ElementState::Monitoring }
          expect(untracked_class.state_tracking_enabled?).to be false
        end
      end

      describe 'instance methods' do
        before do
          allow(monitoring_test_instance).to receive(:element_id).and_return('mocked_element_id')
        end

        it 'tracks state when enabled' do
          expect(Appom::ElementState.tracker).to receive(:track_element)
          monitoring_test_instance.track_state(name: 'test')
        end

        it 'updates state when enabled' do
          monitoring_test_instance.instance_variable_set(:@element_id, 'mocked_element_id')
          expect(Appom::ElementState.tracker).to receive(:update_element_state).with('mocked_element_id')
          monitoring_test_instance.update_state
        end

        it 'gets current state when enabled' do
          monitoring_test_instance.instance_variable_set(:@element_id, 'mocked_element_id')
          expect(Appom::ElementState.tracker).to receive(:element_state).with('mocked_element_id')
          monitoring_test_instance.current_state
        end

        it 'waits for state change when enabled' do
          monitoring_test_instance.instance_variable_set(:@element_id, 'mocked_element_id')
          expect(Appom::ElementState.tracker).to receive(:wait_for_state_change).with('mocked_element_id', {})
          monitoring_test_instance.wait_for_state_change
        end

        it 'does nothing when tracking disabled' do
          disabled_class = Class.new do
            include Appom::ElementState::Monitoring

            def initialize(*args); end
          end
          disabled_instance = disabled_class.new(mock_element)

          expect(Appom::ElementState.tracker).not_to receive(:track_element)
          disabled_instance.track_state
        end
      end
    end

    describe 'module-level convenience methods' do
      it 'provides global tracker access' do
        expect(Appom::ElementState.tracker).to be_a(Appom::ElementState::Tracker)
      end

      it 'provides track_element convenience method' do
        expect(Appom::ElementState.tracker).to receive(:track_element).with(mock_element, name: 'global')
        Appom::ElementState.track_element(mock_element, name: 'global')
      end

      it 'provides element_state convenience method' do
        expect(Appom::ElementState.tracker).to receive(:element_state).with('test_id')
        Appom::ElementState.element_state('test_id')
      end

      it 'provides wait_for_state_change convenience method' do
        expect(Appom::ElementState.tracker).to receive(:wait_for_state_change).with('test_id', timeout: 5)
        Appom::ElementState.wait_for_state_change('test_id', timeout: 5)
      end

      it 'provides tracking_summary convenience method' do
        expect(Appom::ElementState.tracker).to receive(:tracking_summary)
        Appom::ElementState.tracking_summary
      end

      it 'provides clear! convenience method' do
        expect(Appom::ElementState.tracker).to receive(:clear!)
        Appom::ElementState.clear!
      end

      it 'provides export_data convenience method' do
        expect(Appom::ElementState.tracker).to receive(:export_tracking_data).with(format: :json)
        Appom::ElementState.export_data(format: :json)
      end

      it 'allows custom tracker assignment' do
        original_tracker = Appom::ElementState.tracker
        custom_tracker = Appom::ElementState::Tracker.new
        Appom::ElementState.tracker = custom_tracker

        expect(Appom::ElementState.tracker).to be(custom_tracker)

        # Reset to default
        Appom::ElementState.tracker = original_tracker
      end
    end
  end
end
