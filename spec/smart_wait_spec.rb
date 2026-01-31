require 'spec_helper'

RSpec.describe Appom::SmartWait do
  let(:mock_element) { double('element') }
  let(:mock_driver) { double('driver') }
  
  before do
    allow(mock_element).to receive(:displayed?).and_return(true)
    allow(mock_element).to receive(:enabled?).and_return(true)
    allow(mock_element).to receive(:text).and_return('Button')
    allow(mock_element).to receive(:attribute).with(:value).and_return('test_value')
  end

  describe Appom::SmartWait::WaitConditions do
    describe '.element_visible' do
      it 'creates a visibility condition' do
        condition = Appom::SmartWait::WaitConditions.element_visible(mock_element)
        
        expect(condition.call).to be true
        
        allow(mock_element).to receive(:displayed?).and_return(false)
        expect(condition.call).to be false
      end

      it 'handles exceptions gracefully' do
        allow(mock_element).to receive(:displayed?).and_raise(StandardError, 'Element not found')
        condition = Appom::SmartWait::WaitConditions.element_visible(mock_element)
        
        expect(condition.call).to be false
      end
    end

    describe '.element_enabled' do
      it 'creates an enabled condition' do
        condition = Appom::SmartWait::WaitConditions.element_enabled(mock_element)
        
        expect(condition.call).to be true
        
        allow(mock_element).to receive(:enabled?).and_return(false)
        expect(condition.call).to be false
      end
    end

    describe '.element_clickable' do
      it 'creates a clickable condition (visible and enabled)' do
        condition = Appom::SmartWait::WaitConditions.element_clickable(mock_element)
        
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
        condition = Appom::SmartWait::WaitConditions.text_present(mock_element, 'Button')
        
        expect(condition.call).to be true
        
        condition = Appom::SmartWait::WaitConditions.text_present(mock_element, 'NotPresent')
        expect(condition.call).to be false
      end

      it 'supports regex patterns' do
        condition = Appom::SmartWait::WaitConditions.text_present(mock_element, /^But/)
        expect(condition.call).to be true
        
        condition = Appom::SmartWait::WaitConditions.text_present(mock_element, /^Not/)
        expect(condition.call).to be false
      end
    end

    describe '.text_changed' do
      it 'creates a text change condition' do
        initial_text = 'Initial'
        allow(mock_element).to receive(:text).and_return(initial_text)
        
        condition = Appom::SmartWait::WaitConditions.text_changed(mock_element, initial_text)
        
        expect(condition.call).to be false
        
        allow(mock_element).to receive(:text).and_return('Changed')
        expect(condition.call).to be true
      end
    end

    describe '.attribute_contains' do
      it 'creates an attribute condition' do
        condition = Appom::SmartWait::WaitConditions.attribute_contains(mock_element, :value, 'test')
        
        expect(condition.call).to be true
        
        condition = Appom::SmartWait::WaitConditions.attribute_contains(mock_element, :value, 'missing')
        expect(condition.call).to be false
      end
    end

    describe '.custom_condition' do
      it 'creates a custom condition from block' do
        condition = Appom::SmartWait::WaitConditions.custom_condition do
          mock_element.text == 'Button'
        end
        
        expect(condition.call).to be true
        
        allow(mock_element).to receive(:text).and_return('Other')
        expect(condition.call).to be false
      end
    end

    describe '.any_condition' do
      it 'creates a condition that passes if any sub-condition passes' do
        condition1 = Appom::SmartWait::WaitConditions.text_present(mock_element, 'NotPresent')
        condition2 = Appom::SmartWait::WaitConditions.element_visible(mock_element)
        
        any_condition = Appom::SmartWait::WaitConditions.any_condition([condition1, condition2])
        
        expect(any_condition.call).to be true
      end
    end

    describe '.all_conditions' do
      it 'creates a condition that passes only if all sub-conditions pass' do
        condition1 = Appom::SmartWait::WaitConditions.element_visible(mock_element)
        condition2 = Appom::SmartWait::WaitConditions.element_enabled(mock_element)
        
        all_condition = Appom::SmartWait::WaitConditions.all_conditions([condition1, condition2])
        
        expect(all_condition.call).to be true
        
        allow(mock_element).to receive(:enabled?).and_return(false)
        expect(all_condition.call).to be false
      end
    end
  end

  describe Appom::SmartWait::ConditionalWait do
    let(:conditional_wait) { Appom::SmartWait::ConditionalWait.new }

    describe '#wait_until' do
      it 'waits until condition is true' do
        call_count = 0
        condition = -> do
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
        end.to raise_error(Appom::Exceptions::TimeoutError, /Condition not met within 0.2s/)
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
        condition = -> do
          call_count += 1
          if call_count < 3
            raise StandardError, 'Temporary error'
          else
            true
          end
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
        end.to raise_error(Appom::Exceptions::TimeoutError)
        
        duration = Time.now - start_time
        expect(duration).to be_within(0.05).of(0.15)
      end
    end

    describe '#wait_while' do
      it 'waits while condition is true' do
        call_count = 0
        condition = -> do
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
        end.to raise_error(Appom::Exceptions::TimeoutError, /Condition remained true for 0.2s/)
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
        condition = -> do
          call_count += 1
          call_count > 3 # Becomes true after 3 calls and stays true
        end
        
        result = conditional_wait.wait_for_stable_condition(
          condition, 
          stable_duration: 0.15,
          timeout: 5,
          interval: 0.05
        )
        
        expect(result).to be true
        expect(call_count).to be >= 6 # At least 3 calls to become true + 3 more for stability
      end

      it 'resets stability timer when condition changes' do
        flip_at_call = 0
        call_count = 0
        
        condition = -> do
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
          interval: 0.05
        )
        
        expect(result).to be true
        expect(flip_at_call).to eq(5) # Condition did flip
      end
    end
  end

  describe 'Global SmartWait module' do
    before { allow(Appom::SmartWait).to receive(:conditional_wait).and_call_original }

    describe '.wait_until' do
      it 'uses global conditional wait instance' do
        condition = -> { true }
        result = Appom::SmartWait.wait_until(condition, timeout: 1)
        
        expect(result).to be true
      end
    end

    describe '.wait_for_element_visible' do
      it 'waits for element to be visible' do
        result = Appom::SmartWait.wait_for_element_visible(mock_element, timeout: 1)
        
        expect(result).to be true
      end

      it 'raises timeout error when element stays invisible' do
        allow(mock_element).to receive(:displayed?).and_return(false)
        
        expect do
          Appom::SmartWait.wait_for_element_visible(mock_element, timeout: 0.1)
        end.to raise_error(Appom::Exceptions::TimeoutError)
      end
    end

    describe '.wait_for_element_clickable' do
      it 'waits for element to be clickable' do
        result = Appom::SmartWait.wait_for_element_clickable(mock_element, timeout: 1)
        
        expect(result).to be true
      end
    end

    describe '.wait_for_text_present' do
      it 'waits for text to be present' do
        result = Appom::SmartWait.wait_for_text_present(mock_element, 'Button', timeout: 1)
        
        expect(result).to be true
      end

      it 'works with regex patterns' do
        result = Appom::SmartWait.wait_for_text_present(mock_element, /^But/, timeout: 1)
        
        expect(result).to be true
      end
    end

    describe '.wait_for_text_to_change' do
      it 'waits for text to change from initial value' do
        initial_text = mock_element.text
        
        # Simulate text change after delay
        Thread.new do
          sleep(0.1)
          allow(mock_element).to receive(:text).and_return('Changed Text')
        end
        
        result = Appom::SmartWait.wait_for_text_to_change(mock_element, initial_text, timeout: 1)
        
        expect(result).to be true
      end
    end

    describe '.wait_for_stable_element' do
      it 'waits for element to be in stable state' do
        result = Appom::SmartWait.wait_for_stable_element(
          mock_element,
          stable_duration: 0.1,
          timeout: 1
        )
        
        expect(result).to be true
      end
    end

    describe 'exponential backoff' do
      let(:conditional_wait) { Appom::SmartWait::ConditionalWait.new }

      it 'increases wait intervals with backoff' do
        call_times = []
        condition = -> do
          call_times << Time.now
          call_times.size >= 4
        end
        
        conditional_wait.wait_until(
          condition,
          timeout: 5,
          interval: 0.1,
          backoff_factor: 2.0,
          max_interval: 0.5
        )
        
        expect(call_times.size).to eq(4)
        
        # Check that intervals increase (with some tolerance for timing)
        intervals = call_times.each_cons(2).map { |t1, t2| t2 - t1 }
        expect(intervals[1]).to be > intervals[0] * 1.8
      end

      it 'caps interval at max_interval' do
        call_times = []
        condition = -> do
          call_times << Time.now
          call_times.size >= 6
        end
        
        conditional_wait.wait_until(
          condition,
          timeout: 5,
          interval: 0.1,
          backoff_factor: 3.0,
          max_interval: 0.2
        )
        
        intervals = call_times.each_cons(2).map { |t1, t2| t2 - t1 }
        
        # Later intervals should not exceed max_interval
        expect(intervals.last).to be <= 0.25 # Allow some tolerance
      end
    end
  end

  describe 'Smart wait with real timing' do
    it 'accurately times wait operations', :slow do
      start_time = Time.now
      
      call_count = 0
      condition = -> do
        call_count += 1
        call_count >= 3
      end
      
      Appom::SmartWait.wait_until(condition, timeout: 5, interval: 0.1)
      
      duration = Time.now - start_time
      expect(duration).to be_between(0.15, 0.35) # Allow for timing variations
    end

    it 'handles timeout scenarios accurately', :slow do
      start_time = Time.now
      condition = -> { false }
      
      expect do
        Appom::SmartWait.wait_until(condition, timeout: 0.2, interval: 0.05)
      end.to raise_error(Appom::Exceptions::TimeoutError)
      
      duration = Time.now - start_time
      expect(duration).to be_between(0.18, 0.25) # Should be close to timeout
    end
  end
end