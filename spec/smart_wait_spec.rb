# frozen_string_literal: true

require 'spec_helper'

# Import exception constants for tests
ElementNotFoundError = Appom::ElementNotFoundError

RSpec.describe Appom::SmartWait do
  let(:mock_element) { double('element') }
  let(:mock_driver) { double('driver') }

  before do
    allow(mock_element).to receive_messages(displayed?: true, enabled?: true, text: 'Button')
    allow(mock_element).to receive(:attribute).with(:value).and_return('test_value')
  end

  describe Appom::SmartWait::WaitConditions do
    describe '.element_visible' do
      it 'creates a visibility condition' do
        condition = described_class.element_visible(mock_element)

        expect(condition.call).to be true

        allow(mock_element).to receive(:displayed?).and_return(false)
        expect(condition.call).to be false
      end

      it 'handles exceptions gracefully' do
        allow(mock_element).to receive(:displayed?).and_raise(StandardError, 'Element not found')
        condition = described_class.element_visible(mock_element)

        expect(condition.call).to be false
      end
    end

    describe '.element_enabled' do
      it 'creates an enabled condition' do
        condition = described_class.element_enabled(mock_element)

        expect(condition.call).to be true

        allow(mock_element).to receive(:enabled?).and_return(false)
        expect(condition.call).to be false
      end
    end

    describe '.element_clickable' do
      it 'creates a clickable condition (visible and enabled)' do
        condition = described_class.element_clickable(mock_element)

        expect(condition.call).to be true

        allow(mock_element).to receive(:enabled?).and_return(false)
        expect(condition.call).to be false

        allow(mock_element).to receive(:enabled?).and_return(true)
        allow(mock_element).to receive(:displayed?).and_return(false)
        expect(condition.call).to be false
      end
    end

    describe '.text_present' do
      it 'creates a text presence condition' do
        condition = described_class.text_present(mock_element, 'Button')

        expect(condition.call).to be true

        condition = described_class.text_present(mock_element, 'NotPresent')
        expect(condition.call).to be false
      end

      it 'supports regex patterns' do
        condition = described_class.text_present(mock_element, /^But/)
        expect(condition.call).to be true

        condition = described_class.text_present(mock_element, /^Not/)
        expect(condition.call).to be false
      end
    end

    describe '.text_changed' do
      it 'creates a text change condition' do
        initial_text = 'Initial'
        allow(mock_element).to receive(:text).and_return(initial_text)

        condition = described_class.text_changed(mock_element, initial_text)

        expect(condition.call).to be false

        allow(mock_element).to receive(:text).and_return('Changed')
        expect(condition.call).to be true
      end
    end

    describe '.attribute_contains' do
      it 'creates an attribute condition' do
        condition = described_class.attribute_contains(mock_element, :value, 'test')

        expect(condition.call).to be true

        condition = described_class.attribute_contains(mock_element, :value, 'missing')
        expect(condition.call).to be false
      end

      it 'handles nil attribute values' do
        allow(mock_element).to receive(:attribute).with(:missing_attr).and_return(nil)
        condition = described_class.attribute_contains(mock_element, :missing_attr, 'any')

        expect(condition.call).to be false
      end

      it 'handles exceptions gracefully' do
        allow(mock_element).to receive(:attribute).and_raise(StandardError, 'Attribute error')
        condition = described_class.attribute_contains(mock_element, :value, 'test')

        expect(condition.call).to be false
      end
    end

    describe '.custom_condition' do
      it 'returns the provided block as condition' do
        test_block = -> { true }
        condition = described_class.custom_condition(&test_block)

        expect(condition).to eq(test_block)
      end
    end

    describe '.any_condition (returns true/false)' do
      it 'returns true if any condition is true' do
        condition1 = -> { false }
        condition2 = -> { true }
        condition3 = -> { false }

        combined = described_class.any_condition([condition1, condition2, condition3])

        expect(combined.call).to be true
      end

      it 'returns false if all conditions are false' do
        condition1 = -> { false }
        condition2 = -> { false }

        combined = described_class.any_condition([condition1, condition2])

        expect(combined.call).to be false
      end
    end

    describe '.all_conditions' do
      it 'returns true if all conditions are true' do
        condition1 = -> { true }
        condition2 = -> { true }

        combined = described_class.all_conditions([condition1, condition2])

        expect(combined.call).to be true
      end

      it 'returns false if any condition is false' do
        condition1 = -> { true }
        condition2 = -> { false }

        combined = described_class.all_conditions([condition1, condition2])

        expect(combined.call).to be false
      end
    end

    describe '.element_invisible' do
      it 'returns true when element is not displayed' do
        allow(mock_element).to receive(:displayed?).and_return(false)
        condition = described_class.element_invisible(mock_element)

        expect(condition.call).to be true
      end

      it 'returns false when element is displayed' do
        allow(mock_element).to receive(:displayed?).and_return(true)
        condition = described_class.element_invisible(mock_element)

        expect(condition.call).to be false
      end

      it 'returns true when element raises error (not found)' do
        allow(mock_element).to receive(:displayed?).and_raise(StandardError, 'Element not found')
        condition = described_class.element_invisible(mock_element)

        expect(condition.call).to be true
      end
    end

    describe '.attribute_equals' do
      it 'returns true when attribute equals expected value' do
        allow(mock_element).to receive(:attribute).with(:class).and_return('expected_class')
        condition = described_class.attribute_equals(mock_element, :class, 'expected_class')

        expect(condition.call).to be true
      end

      it 'returns false when attribute does not equal expected value' do
        allow(mock_element).to receive(:attribute).with(:class).and_return('different_class')
        condition = described_class.attribute_equals(mock_element, :class, 'expected_class')

        expect(condition.call).to be false
      end

      it 'handles exceptions gracefully' do
        allow(mock_element).to receive(:attribute).and_raise(StandardError, 'Attribute error')
        condition = described_class.attribute_equals(mock_element, :class, 'any')

        expect(condition.call).to be false
      end
    end

    describe '.custom_condition' do
      it 'creates a custom condition from block' do
        condition = described_class.custom_condition do
          mock_element.text == 'Button'
        end

        expect(condition.call).to be true

        allow(mock_element).to receive(:text).and_return('Other')
        expect(condition.call).to be false
      end
    end

    describe '.any_condition' do
      it 'creates a condition that passes if any sub-condition passes' do
        condition1 = described_class.text_present(mock_element, 'NotPresent')
        condition2 = described_class.element_visible(mock_element)

        any_condition = described_class.any_condition([condition1, condition2])

        expect(any_condition.call).to be true
      end
    end

    describe '.all_conditions' do
      it 'creates a condition that passes only if all sub-conditions pass' do
        condition1 = described_class.element_visible(mock_element)
        condition2 = described_class.element_enabled(mock_element)

        all_condition = described_class.all_conditions([condition1, condition2])

        expect(all_condition.call).to be true

        allow(mock_element).to receive(:enabled?).and_return(false)
        expect(all_condition.call).to be false
      end
    end
  end

  describe Appom::SmartWait::ConditionalWait do
    let(:conditional_wait) { described_class.new }

    describe '#wait_until' do
      it 'waits until condition is true' do
        call_count = 0
        condition = lambda do
          call_count += 1
          call_count >= 3
        end

        start_time = Time.now
        result = conditional_wait.wait_until(condition, timeout: 5, interval: 0.1)
        duration = Time.now - start_time

        expect(result).to be true
        expect(call_count).to eq(3)
        expect(duration).to be >= 0.2
        expect(duration).to be < 1.0
      end

      it 'raises timeout error when condition is never met' do
        condition = -> { false }

        expect do
          conditional_wait.wait_until(condition, timeout: 0.2, interval: 0.1)
        end.to raise_error(Appom::TimeoutError, /Condition not met within 0.2s/)
      end

      it 'returns immediately when condition is already true' do
        condition = -> { true }

        start_time = Time.now
        result = conditional_wait.wait_until(condition, timeout: 5, interval: 0.1)
        duration = Time.now - start_time

        expect(result).to be true
        expect(duration).to be < 0.1
      end

      it 'handles exceptions in condition' do
        call_count = 0
        condition = lambda do
          call_count += 1
          raise StandardError, 'Temporary error' if call_count < 3

          true
        end

        result = conditional_wait.wait_until(condition, timeout: 5, interval: 0.1)

        expect(result).to be true
        expect(call_count).to eq(3)
      end

      it 'supports custom timeout and interval' do
        condition = -> { false }

        start_time = Time.now
        expect do
          conditional_wait.wait_until(condition, timeout: 0.15, interval: 0.05)
        end.to raise_error(Appom::TimeoutError)

        duration = Time.now - start_time
        expect(duration).to be_within(0.05).of(0.15)
      end
    end

    describe '#wait_while' do
      it 'waits while condition is true' do
        call_count = 0
        condition = lambda do
          call_count += 1
          call_count < 3
        end

        result = conditional_wait.wait_while(condition, timeout: 5, interval: 0.1)

        expect(result).to be true
        expect(call_count).to eq(3)
      end

      it 'raises timeout error when condition stays true' do
        condition = -> { true }

        expect do
          conditional_wait.wait_while(condition, timeout: 0.2, interval: 0.1)
        end.to raise_error(Appom::TimeoutError, /Condition remained true for 0.2s/)
      end

      it 'returns immediately when condition is already false' do
        condition = -> { false }

        start_time = Time.now
        result = conditional_wait.wait_while(condition, timeout: 5, interval: 0.1)
        duration = Time.now - start_time

        expect(result).to be true
        expect(duration).to be < 0.1
      end
    end

    describe '#wait_for_stable_condition' do
      it 'waits for condition to remain stable' do
        call_count = 0
        condition = lambda do
          call_count += 1
          call_count > 3 # Becomes true after 3 calls and stays true
        end

        result = conditional_wait.wait_for_stable_condition(
          condition,
          stable_duration: 0.15,
          timeout: 5,
          interval: 0.05,
        )

        expect(result).to be true
        expect(call_count).to be >= 6 # At least 3 calls to become true + 3 more for stability
      end

      it 'resets stability timer when condition changes' do
        flip_at_call = 0
        call_count = 0

        condition = lambda do
          call_count += 1

          # Flip condition at call 5 to test stability reset
          if call_count == 5
            flip_at_call = call_count
            false
          elsif flip_at_call > 0 && call_count > flip_at_call + 2
            true
          else
            call_count > 2
          end
        end

        result = conditional_wait.wait_for_stable_condition(
          condition,
          stable_duration: 0.15,
          timeout: 5,
          interval: 0.05,
        )

        expect(result).to be true
        expect(flip_at_call).to eq(5) # Condition did flip
      end
    end
  end

  describe 'Global SmartWait module' do
    before { allow(described_class).to receive(:conditional_wait).and_call_original }

    describe '.wait_until' do
      it 'uses global conditional wait instance' do
        condition = -> { true }
        result = described_class.wait_until(condition, timeout: 1)

        expect(result).to be true
      end
    end

    describe '.wait_for_element_visible' do
      it 'waits for element to be visible' do
        result = described_class.wait_for_element_visible(mock_element, timeout: 1)

        expect(result).to be true
      end

      it 'raises timeout error when element stays invisible' do
        allow(mock_element).to receive(:displayed?).and_return(false)

        expect do
          described_class.wait_for_element_visible(mock_element, timeout: 0.1)
        end.to raise_error(Appom::TimeoutError)
      end
    end

    describe '.wait_for_element_clickable' do
      it 'waits for element to be clickable' do
        result = described_class.wait_for_element_clickable(mock_element, timeout: 1)

        expect(result).to be true
      end
    end

    describe '.wait_for_text_present' do
      it 'waits for text to be present' do
        result = described_class.wait_for_text_present(mock_element, 'Button', timeout: 1)

        expect(result).to be true
      end

      it 'works with regex patterns' do
        result = described_class.wait_for_text_present(mock_element, /^But/, timeout: 1)

        expect(result).to be true
      end
    end

    describe '.wait_for_text_to_change' do
      it 'waits for text to change from initial value' do
        allow(mock_element).to receive(:text).and_return('Initial', 'Changed')

        result = described_class.wait_for_text_to_change(mock_element, 'Initial', timeout: 1)

        expect(result).to be true
      end
    end

    describe '.wait_for_stable_element' do
      it 'waits for element to be stable' do
        result = described_class.wait_for_stable_element(mock_element, timeout: 1, stable_duration: 0.1)

        expect(result).to be true
      end
    end
  end

  # Additional comprehensive tests for ConditionalWait
  describe 'Comprehensive ConditionalWait behavior' do
    let(:conditional_wait) { Appom::SmartWait::ConditionalWait.new(timeout: 2, interval: 0.1) }
    let(:mock_page) { double('page') }

    before do
      allow(conditional_wait).to receive(:page).and_return(mock_page)
      allow(conditional_wait).to receive(:log_wait_start)
      allow(conditional_wait).to receive(:log_wait_end)
      allow(mock_page).to receive(:find_element).and_return(mock_element)
      allow(mock_page).to receive(:find_elements).and_return([mock_element])
    end

    describe '#initialize' do
      it 'sets default values' do
        wait = Appom::SmartWait::ConditionalWait.new
        expect(wait.timeout).to eq(Appom.max_wait_time)
        expect(wait.interval).to eq(Appom::SmartWait::DEFAULT_INTERVAL)
        expect(wait.condition_description).to eq('custom condition')
      end

      it 'accepts custom values' do
        wait = Appom::SmartWait::ConditionalWait.new(timeout: 5, interval: 0.5, condition: -> { true }, description: 'test')
        expect(wait.timeout).to eq(5)
        expect(wait.interval).to eq(0.5)
        expect(wait.condition).to be_a(Proc)
        expect(wait.condition_description).to eq('test')
      end

      it 'uses default description when none provided' do
        wait = Appom::SmartWait::ConditionalWait.new(condition: -> { true })
        expect(wait.condition_description).to eq('custom condition')
      end
    end

    describe '#for_element' do
      it 'waits for element with condition' do
        condition = lambda(&:displayed?)
        mock_page = double('page')
        wait = Appom::SmartWait::ConditionalWait.new(condition: condition)
        allow(wait).to receive(:page).and_return(mock_page)
        allow(wait).to receive(:log_wait_start)
        allow(wait).to receive(:log_wait_end)
        allow(mock_page).to receive(:find_element).and_return(mock_element)

        result = wait.for_element(:id, 'test')

        expect(result).to eq(mock_element)
        expect(wait).to have_received(:log_wait_start)
        expect(wait).to have_received(:log_wait_end)
      end

      it 'accepts condition as block parameter' do
        result = conditional_wait.for_element(:id, 'test') { |el| el.displayed? }

        expect(result).to eq(mock_element)
      end

      it 'raises ArgumentError when no condition provided' do
        expect do
          conditional_wait.for_element(:id, 'test')
        end.to raise_error(Appom::ArgumentError, 'No condition provided')
      end

      it 'raises ElementNotFoundError on timeout' do
        condition = ->(_el) { false }
        wait = Appom::SmartWait::ConditionalWait.new(timeout: 0.1, condition: condition)

        expect do
          wait.for_element(:id, 'test')
        end.to raise_error(Appom::ElementNotFoundError, /with condition/)
      end

      it 'handles element not found during condition check' do
        mock_page = double('page')
        allow(mock_page).to receive(:find_element).and_raise(StandardError, 'Not found').once
        allow(mock_page).to receive(:find_element).and_return(mock_element)
        condition = ->(el) { el.displayed? }
        wait = Appom::SmartWait::ConditionalWait.new(condition: condition)
        allow(wait).to receive(:page).and_return(mock_page)

        result = wait.for_element(:id, 'test')

        expect(result).to eq(mock_element)
      end
    end

    describe '#for_elements' do
      it 'waits for elements collection with condition' do
        condition = ->(elements) { elements.length > 0 }
        mock_page = double('page')
        wait = Appom::SmartWait::ConditionalWait.new(condition: condition)
        allow(wait).to receive(:page).and_return(mock_page)
        allow(mock_page).to receive(:find_elements).and_return([mock_element])

        result = wait.for_elements(:class_name, 'test')

        expect(result).to eq([mock_element])
      end

      it 'raises ElementNotFoundError on timeout' do
        condition = ->(_elements) { false }
        wait = Appom::SmartWait::ConditionalWait.new(timeout: 0.1, condition: condition)

        expect do
          wait.for_elements(:class_name, 'test')
        end.to raise_error(Appom::ElementNotFoundError, /collection with condition/)
      end
    end

    describe '#for_any_condition' do
      it 'waits for any condition to be met' do
        element1 = double('element1', displayed?: false)
        element2 = double('element2', displayed?: true)

        allow(mock_page).to receive(:find_element).with(:id, 'first').and_return(element1)
        allow(mock_page).to receive(:find_element).with(:id, 'second').and_return(element2)

        condition1 = ->(el) { el.displayed? }
        condition2 = ->(el) { el.displayed? }

        conditions = [
          [[:id, 'first'], condition1],
          [[:id, 'second'], condition2],
        ]

        result = conditional_wait.for_any_condition(*conditions)

        expect(result[:index]).to eq(1)
        expect(result[:element]).to eq(element2)
        expect(result[:find_args]).to eq([:id, 'second'])
      end

      it 'raises ArgumentError when no conditions provided' do
        mock_page = double('page')
        allow(conditional_wait).to receive(:page).and_return(mock_page)
        expect do
          conditional_wait.for_any_condition
        end.to raise_error(ArgumentError, 'No conditions provided')
      end

      it 'raises ElementNotFoundError when no condition is met' do
        mock_page = double('page')
        allow(mock_page).to receive(:find_element).with(:id, 'test').and_return(mock_element)
        condition = ->(_el) { false }
        conditions = [[[:id, 'test'], condition]]
        allow(conditional_wait).to receive(:page).and_return(mock_page)

        expect do
          conditional_wait.for_any_condition(*conditions)
        end.to raise_error(Appom::ElementNotFoundError, /any of/)
      end

      it 'handles exceptions in individual conditions' do
        element2 = double('element2', displayed?: true)

        allow(mock_page).to receive(:find_element).with(:id, 'first').and_raise(StandardError)
        allow(mock_page).to receive(:find_element).with(:id, 'second').and_return(element2)

        condition1 = ->(el) { el.displayed? }
        condition2 = ->(el) { el.displayed? }

        conditions = [
          [[:id, 'first'], condition1],
          [[:id, 'second'], condition2],
        ]

        result = conditional_wait.for_any_condition(*conditions)

        expect(result[:index]).to eq(1)
        expect(result[:element]).to eq(element2)
      end
    end

    describe 'wait methods' do
      describe '#wait_until' do
        it 'waits until condition becomes true' do
          call_count = 0
          condition = lambda do
            call_count += 1
            call_count > 2
          end

          result = conditional_wait.wait_until(condition, timeout: 1)

          expect(result).to be true
        end

        it 'applies exponential backoff when specified' do
          condition = -> { true }
          allow(conditional_wait).to receive(:sleep)

          conditional_wait.wait_until(condition, interval: 0.1, backoff_factor: 2, max_interval: 0.5)

          # Should not sleep since condition is immediately true
          expect(conditional_wait).not_to have_received(:sleep)
        end

        it 'raises timeout error when condition never becomes true' do
          condition = -> { false }

          expect do
            conditional_wait.wait_until(condition, timeout: 0.1)
          end.to raise_error(Appom::TimeoutError, /Condition not met within/)
        end

        it 'raises last error if condition consistently fails with errors' do
          condition = -> { raise StandardError, 'Test error' }

          expect do
            conditional_wait.wait_until(condition, timeout: 0.1)
          end.to raise_error(StandardError, 'Test error')
        end
      end

      describe '#wait_while' do
        it 'waits while condition remains true' do
          call_count = 0
          condition = lambda do
            call_count += 1
            call_count < 3
          end

          result = conditional_wait.wait_while(condition, timeout: 1)

          expect(result).to be true
        end

        it 'raises timeout error when condition remains true' do
          condition = -> { true }

          expect do
            conditional_wait.wait_while(condition, timeout: 0.1)
          end.to raise_error(Appom::TimeoutError, /Condition remained true/)
        end
      end

      describe '#wait_for_stable_condition' do
        it 'waits for condition to remain stable' do
          call_count = 0
          condition = lambda do
            call_count += 1
            call_count > 2
          end

          result = conditional_wait.wait_for_stable_condition(condition, stable_duration: 0.1, timeout: 1)

          expect(result).to be true
        end

        it 'resets stability timer when condition becomes false' do
          call_count = 0
          condition = lambda do
            call_count += 1
            # True, false, true, true...
            call_count != 2
          end

          result = conditional_wait.wait_for_stable_condition(condition, stable_duration: 0.1, timeout: 1)

          expect(result).to be true
        end

        it 'raises timeout error when condition never stabilizes' do
          call_count = 0
          condition = lambda do
            call_count += 1
            call_count.odd?
          end

          expect do
            conditional_wait.wait_for_stable_condition(condition, stable_duration: 0.5, timeout: 1)
          end.to raise_error(Appom::TimeoutError, /did not remain stable/)
        end

        it 'handles condition exceptions' do
          call_count = 0
          condition = lambda do
            call_count += 1
            raise StandardError, 'Condition error' if call_count < 5

            true
          end

          result = conditional_wait.wait_for_stable_condition(condition, stable_duration: 0.1, timeout: 2)

          expect(result).to be true
        end
      end
    end

    describe 'private helper methods' do
      describe '#evaluate_condition_safely' do
        it 'returns success when condition is true' do
          condition = -> { true }

          result = conditional_wait.send(:evaluate_condition_safely, condition, nil)

          expect(result[:success]).to be true
          expect(result[:error]).to be_nil
        end

        it 'returns failure when condition is false' do
          condition = -> { false }
          previous_error = StandardError.new('Previous')

          result = conditional_wait.send(:evaluate_condition_safely, condition, previous_error)

          expect(result[:success]).to be false
          expect(result[:error]).to eq(previous_error)
        end

        it 'captures new error when condition raises' do
          error = StandardError.new('New error')
          condition = -> { raise error }

          result = conditional_wait.send(:evaluate_condition_safely, condition, nil)

          expect(result[:success]).to be false
          expect(result[:error]).to eq(error)
        end
      end

      describe '#apply_backoff' do
        it 'applies backoff factor when specified' do
          result = conditional_wait.send(:apply_backoff, 0.1, 2, 1.0)
          expect(result).to eq(0.2)
        end

        it 'respects max interval' do
          result = conditional_wait.send(:apply_backoff, 1.0, 3, 2.0)
          expect(result).to eq(2.0)
        end

        it 'returns current interval when no backoff specified' do
          result = conditional_wait.send(:apply_backoff, 0.5, nil, nil)
          expect(result).to eq(0.5)
        end
      end

      describe '#_find_element and #_find_elements' do
        context 'when page method available' do
          it 'uses page to find element' do
            result = conditional_wait.send(:_find_element, :id, 'test')
            expect(result).to eq(mock_element)
            expect(mock_page).to have_received(:find_element).with(:id, 'test')
          end

          it 'uses page to find elements' do
            result = conditional_wait.send(:_find_elements, :class_name, 'test')
            expect(result).to eq([mock_element])
            expect(mock_page).to have_received(:find_elements).with(:class_name, 'test')
          end
        end

        context 'when page method not available' do
          before do
            allow(conditional_wait).to receive(:respond_to?).with(:page).and_return(false)
            allow(Appom.driver).to receive(:find_element).and_return(mock_element)
            allow(Appom.driver).to receive(:find_elements).and_return([mock_element])
          end

          it 'uses Appom.driver to find element' do
            result = conditional_wait.send(:_find_element, :id, 'test')
            expect(result).to eq(mock_element)
            expect(Appom.driver).to have_received(:find_element).with(:id, 'test')
          end

          it 'uses Appom.driver to find elements' do
            result = conditional_wait.send(:_find_elements, :class_name, 'test')
            expect(result).to eq([mock_element])
            expect(Appom.driver).to have_received(:find_elements).with(:class_name, 'test')
          end
        end
      end
    end
  end

  # Factory methods tests
  describe 'SmartWait factory methods' do
    before do
      allow(Appom::SmartWait::ConditionalWait).to receive(:new).and_call_original
      allow_any_instance_of(Appom::SmartWait::ConditionalWait).to receive(:for_element).and_return(mock_element)
      allow_any_instance_of(Appom::SmartWait::ConditionalWait).to receive(:for_elements).and_return([mock_element])
      # Ensure no factory method test can hang: stub all waits to return quickly
      allow_any_instance_of(Appom::SmartWait::ConditionalWait).to receive(:wait_until).and_return(true)
      allow_any_instance_of(Appom::SmartWait::ConditionalWait).to receive(:wait_while).and_return(true)
      allow_any_instance_of(Appom::SmartWait::ConditionalWait).to receive(:wait_for_stable_condition).and_return(true)
    end

    describe '.until_clickable' do
      it 'creates wait with clickable condition' do
        # Should not hang, should call ConditionalWait.new and for_element
        result = described_class.until_clickable(:id, 'test', timeout: 5)

        expect(result).to eq(mock_element)
        expect(Appom::SmartWait::ConditionalWait).to have_received(:new).with(
          timeout: 5,
          condition: kind_of(Proc),
          description: 'clickable',
        )
      end
    end

    describe '.until_text_matches' do
      it 'creates wait with text matching condition for exact match' do
        result = described_class.until_text_matches(:id, 'test', text: 'Button', exact: true, timeout: 3)

        expect(result).to eq(mock_element)
        expect(Appom::SmartWait::ConditionalWait).to have_received(:new).with(
          timeout: 3,
          condition: kind_of(Proc),
          description: "text equals 'Button'",
        )
      end

      it 'creates wait with text matching condition for partial match' do
        described_class.until_text_matches(:id, 'test', text: 'But', exact: false)

        expect(Appom::SmartWait::ConditionalWait).to have_received(:new).with(
          timeout: Appom.max_wait_time,
          condition: kind_of(Proc),
          description: "text matches 'But'",
        )
      end
    end

    describe '.until_invisible' do
      it 'creates wait with invisible condition' do
        result = described_class.until_invisible(:id, 'test', timeout: 8)

        expect(result).to eq(mock_element)
        expect(Appom::SmartWait::ConditionalWait).to have_received(:new).with(
          timeout: 8,
          condition: kind_of(Proc),
          description: 'invisible',
        )
      end
    end

    describe '.until_count_equals' do
      it 'creates wait with count condition' do
        result = described_class.until_count_equals(:class_name, 'item', count: 5, timeout: 10)

        expect(result).to eq([mock_element])
        expect(Appom::SmartWait::ConditionalWait).to have_received(:new).with(
          timeout: 10,
          condition: kind_of(Proc),
          description: 'count equals 5',
        )
      end
    end

    describe '.until_condition' do
      it 'creates wait with custom condition' do
        custom_condition = -> { true }
        result = described_class.until_condition(:id, 'test', timeout: 7, description: 'my condition', &custom_condition)

        expect(result).to eq(mock_element)
        expect(Appom::SmartWait::ConditionalWait).to have_received(:new).with(
          timeout: 7,
          condition: custom_condition,
          description: 'my condition',
        )
      end
    end
  end
end
