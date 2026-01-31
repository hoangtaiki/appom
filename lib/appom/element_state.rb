# frozen_string_literal: true

# Element state tracking for Appom automation framework
# Tracks element state changes and provides monitoring capabilities
module Appom::ElementState
  # Tracks element states and changes over time
  class Tracker
    include Appom::Logging

    attr_reader :tracked_elements, :state_history

    def initialize
      @tracked_elements = {}
      @state_history = []
      @observers = []
      @tracking_enabled = true
    end

    # Start tracking an element
    def track_element(element, name: nil, context: {})
      element_id = generate_element_id(element, name)

      state = capture_element_state(element)

      @tracked_elements[element_id] = {
        element: element,
        name: name || element_id,
        context: context,
        first_seen: Time.now,
        last_updated: Time.now,
        current_state: state,
        previous_states: [],
        change_count: 0,
      }

      log_debug("Started tracking element: #{name || element_id}")
      notify_observers(:element_tracked, element_id, state)

      element_id
    end

    # Update element state and detect changes
    def update_element_state(element_id) # rubocop:disable Metrics/AbcSize
      return unless @tracking_enabled

      tracked = @tracked_elements[element_id]
      return unless tracked

      begin
        new_state = capture_element_state(tracked[:element])
        old_state = tracked[:current_state]

        if state_changed?(old_state, new_state)
          # Store previous state
          tracked[:previous_states] << {
            state: old_state,
            timestamp: tracked[:last_updated],
            duration: Time.now - tracked[:last_updated],
          }

          # Keep only last 10 states
          tracked[:previous_states] = tracked[:previous_states].last(10)

          # Update current state
          tracked[:current_state] = new_state
          tracked[:last_updated] = Time.now
          tracked[:change_count] += 1

          # Record in history
          change_event = {
            timestamp: Time.now,
            element_id: element_id,
            element_name: tracked[:name],
            old_state: old_state,
            new_state: new_state,
            changes: calculate_changes(old_state, new_state),
          }

          @state_history << change_event
          @state_history = @state_history.last(1000) # Keep last 1000 changes

          log_debug("Element state changed: #{tracked[:name]}", change_event[:changes])
          notify_observers(:state_changed, element_id, change_event)

          change_event
        end
      rescue StandardError => e
        log_warn("Failed to update element state: #{e.message}")
        nil
      end
    end

    # Get current state of tracked element
    def element_state(element_id)
      tracked = @tracked_elements[element_id]
      return nil unless tracked

      # Update state before returning
      update_element_state(element_id)
      tracked[:current_state]
    end

    # Get element state history
    def element_history(element_id, limit: 50)
      @state_history
        .select { |event| event[:element_id] == element_id }
        .last(limit)
    end

    # Wait for element state change
    def wait_for_state_change(element_id, expected_changes: {}, timeout: 10, interval: 0.5)
      start_time = Time.now

      loop do
        current_state = element_state(element_id)

        return current_state if expected_changes.all? { |key, value| current_state&.dig(key) == value }

        if Time.now - start_time > timeout
          raise Appom::TimeoutError,
                "Element state did not change as expected within #{timeout}s. " \
                "Expected: #{expected_changes}, Current: #{current_state}"
        end

        sleep interval
      end
    end

    # Wait for element to be in specific state
    def wait_for_state(element_id, condition, timeout: 10, interval: 0.5)
      start_time = Time.now

      loop do
        current_state = element_state(element_id)

        result = case condition
                 when Proc
                   condition.call(current_state)
                 when Hash
                   condition.all? { |key, value| current_state&.dig(key) == value }
                 else
                   false
                 end

        return current_state if result

        if Time.now - start_time > timeout
          raise Appom::TimeoutError,
                "Element did not reach expected state within #{timeout}s. Current: #{current_state}"
        end

        sleep interval
      end
    end

    # Stop tracking an element
    def stop_tracking(element_id)
      tracked = @tracked_elements.delete(element_id)
      return unless tracked

      log_debug("Stopped tracking element: #{tracked[:name]}")
      notify_observers(:element_untracked, element_id)

      # Return final summary
      {
        name: tracked[:name],
        tracking_duration: Time.now - tracked[:first_seen],
        change_count: tracked[:change_count],
        final_state: tracked[:current_state],
      }
    end

    # Get tracking summary
    def tracking_summary
      {
        total_tracked: @tracked_elements.count,
        total_changes: @state_history.count,
        most_active: most_active_elements(5),
        recent_changes: @state_history.last(10),
        tracking_enabled: @tracking_enabled,
      }
    end

    # Find elements by state criteria
    def find_elements_by_state(criteria)
      @tracked_elements.select do |_element_id, tracked|
        current_state = tracked[:current_state]

        case criteria
        when Hash
          criteria.all? { |key, value| current_state&.dig(key) == value }
        when Proc
          criteria.call(current_state)
        else
          false
        end
      end
    end

    # Add state change observer
    def add_observer(&block)
      @observers << block
    end

    # Remove observer
    def remove_observer(observer)
      @observers.delete(observer)
    end

    # Enable/disable tracking
    def tracking_enabled=(enabled)
      @tracking_enabled = enabled
      log_info("Element state tracking #{enabled ? 'enabled' : 'disabled'}")
    end

    # Clear all tracking data
    def clear!
      @tracked_elements.clear
      @state_history.clear
      log_info('Element state tracking data cleared')
    end

    # Export tracking data
    def export_tracking_data(file_path: nil, format: :json)
      file_path ||= "element_state_tracking_#{Time.now.strftime('%Y%m%d_%H%M%S')}.#{format}"

      data = {
        exported_at: Time.now,
        summary: tracking_summary,
        tracked_elements: serialize_tracked_elements,
        state_history: @state_history,
      }

      case format
      when :json
        File.write(file_path, JSON.pretty_generate(data))
      when :yaml
        File.write(file_path, YAML.dump(data))
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end

      log_info("Element state tracking data exported to #{file_path}")
      file_path
    end

    private

    def generate_element_id(element, name)
      if name
        name.to_s
      else
        # Try to generate meaningful ID from element
        begin
          attrs = []
          attrs << element.attribute(:id) if element.attribute(:id)
          attrs << element.attribute(:class) if element.attribute(:class)
          attrs << element.tag_name if element.respond_to?(:tag_name)

          id = attrs.any? ? attrs.join('_') : "element_#{element.object_id}"
          id.gsub(/[^\w\-_]/, '_')
        rescue StandardError
          "element_#{element.object_id}"
        end
      end
    end

    def capture_element_state(element)
      state = {
        captured_at: Time.now,
        exists: false,
        displayed: false,
        enabled: false,
        selected: false,
        text: nil,
        attributes: {},
        location: nil,
        size: nil,
      }

      begin
        state[:exists] = element.respond_to?(:displayed?) || element.respond_to?(:enabled?)

        if state[:exists]
          state[:displayed] = element.displayed? if element.respond_to?(:displayed?)
          state[:enabled] = element.enabled? if element.respond_to?(:enabled?)
          state[:selected] = element.selected? if element.respond_to?(:selected?)
          state[:text] = element.text if element.respond_to?(:text)

          # Capture common attributes
          if element.respond_to?(:attribute)
            %w[id class name type value placeholder].each do |attr|
              value = element.attribute(attr.to_sym) || element.attribute(attr)
              state[:attributes][attr.to_sym] = value if value
            end
          end

          # Capture location and size
          state[:location] = element.location if element.respond_to?(:location)

          state[:size] = element.size if element.respond_to?(:size)
        end
      rescue StandardError => e
        state[:error] = e.message
        state[:exists] = false
      end

      state
    end

    def state_changed?(old_state, new_state)
      # Compare relevant state properties, excluding timestamp fields
      comparison_keys = %i[exists displayed enabled selected text attributes location size]

      comparison_keys.any? { |key| old_state[key] != new_state[key] }
    end

    def calculate_changes(old_state, new_state)
      changes = {}

      old_state.each do |key, old_value|
        new_value = new_state[key]

        next unless old_value != new_value

        changes[key] = {
          from: old_value,
          to: new_value,
        }
      end

      changes
    end

    def most_active_elements(limit)
      @tracked_elements
        .map { |_id, tracked| [tracked[:name], tracked[:change_count]] }
        .sort_by { |_, count| -count }
        .first(limit)
        .to_h
    end

    def notify_observers(event_type, *args)
      @observers.each do |observer|
        observer.call(event_type, *args)
      rescue StandardError => e
        log_error("Observer error: #{e.message}")
      end
    end

    def serialize_tracked_elements
      @tracked_elements.transform_values do |tracked|
        {
          name: tracked[:name],
          context: tracked[:context],
          first_seen: tracked[:first_seen],
          last_updated: tracked[:last_updated],
          current_state: tracked[:current_state],
          change_count: tracked[:change_count],
          previous_states_count: tracked[:previous_states].size,
        }
      end
    end
  end

  # Element state monitoring mixin
  module Monitoring
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class methods for element state tracking
    module ClassMethods
      def track_state_changes
        @state_tracking_enabled = true
      end

      def state_tracking_enabled?
        @state_tracking_enabled ||= false
      end
    end

    # Track this element's state
    def track_state(name: nil, context: {})
      return unless self.class.state_tracking_enabled?

      ElementState.tracker.track_element(self, name: name, context: context)
    end

    # Update state and return changes
    def update_state
      return unless self.class.state_tracking_enabled?

      ElementState.tracker.update_element_state(element_id) if defined?(@element_id)
    end

    # Get current state
    def current_state
      return unless self.class.state_tracking_enabled?

      ElementState.tracker.element_state(element_id) if defined?(@element_id)
    end

    # Wait for state change
    def wait_for_state_change(**)
      return unless self.class.state_tracking_enabled?

      ElementState.tracker.wait_for_state_change(element_id, **) if defined?(@element_id)
    end

    private

    def element_id
      @element_id ||= ElementState.tracker.generate_element_id(self, nil)
    end
  end

  # Global state tracker
  class << self
    attr_writer :tracker

    def tracker
      @tracker ||= Tracker.new
    end

    # Convenience methods
    def track_element(element, **)
      tracker.track_element(element, **)
    end

    def element_state(element_id)
      tracker.element_state(element_id)
    end

    def wait_for_state_change(element_id, **)
      tracker.wait_for_state_change(element_id, **)
    end

    def tracking_summary
      tracker.tracking_summary
    end

    def clear!
      tracker.clear!
    end

    def export_data(**)
      tracker.export_tracking_data(**)
    end
  end
end
