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
        expect(enabled_elements.keys.first).to include('enabled_element')
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
  end
end
