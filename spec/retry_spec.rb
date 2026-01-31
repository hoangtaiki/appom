# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Appom::Retry do
  describe '::RetryConfig' do
    let(:config) { described_class::RetryConfig.new }

    describe '#initialize' do
      it 'sets default values' do
        expect(config.max_attempts).to eq(3)
        expect(config.base_delay).to eq(0.5)
        expect(config.backoff_multiplier).to eq(1.5)
        expect(config.max_delay).to eq(30)
        expect(config.retry_on_exceptions).to eq([Appom::ElementNotFoundError, Appom::ElementStateError, Appom::WaitError, StandardError])
        expect(config.retry_if).to be_nil
        expect(config.on_retry).to be_nil
      end
    end

    describe 'attribute accessors' do
      it 'allows setting and getting max_attempts' do
        config.max_attempts = 5
        expect(config.max_attempts).to eq(5)
      end

      it 'allows setting and getting base_delay' do
        config.base_delay = 1.0
        expect(config.base_delay).to eq(1.0)
      end

      it 'allows setting and getting backoff_multiplier' do
        config.backoff_multiplier = 2.0
        expect(config.backoff_multiplier).to eq(2.0)
      end

      it 'allows setting and getting max_delay' do
        config.max_delay = 60
        expect(config.max_delay).to eq(60)
      end

      it 'allows setting and getting retry_on_exceptions' do
        config.retry_on_exceptions = [RuntimeError]
        expect(config.retry_on_exceptions).to eq([RuntimeError])
      end

      it 'allows setting and getting retry_if' do
        condition = ->(_e, _attempt) { true }
        config.retry_if = condition
        expect(config.retry_if).to eq(condition)
      end

      it 'allows setting and getting on_retry' do
        callback = ->(_e, attempt, _delay) {}
        config.on_retry = callback
        expect(config.on_retry).to eq(callback)
      end
    end
  end

  describe '.with_retry' do
    let(:config) { described_class::RetryConfig.new }

    context 'when block succeeds' do
      it 'returns the block result' do
        result = described_class.with_retry(config) { 'success' }
        expect(result).to eq('success')
      end

      it 'does not retry on success' do
        attempt_count = 0
        described_class.with_retry(config) { attempt_count += 1 }
        expect(attempt_count).to eq(1)
      end
    end

    context 'when block fails' do
      it 'retries up to max_attempts on retriable exceptions' do
        attempt_count = 0
        config.max_attempts = 3

        expect do
          described_class.with_retry(config) do
            attempt_count += 1
            raise StandardError, 'Test error'
          end
        end.to raise_error(StandardError, 'Test error')

        expect(attempt_count).to eq(3)
      end

      it 'uses exponential backoff with multiplier' do
        config.base_delay = 0.1
        config.backoff_multiplier = 2.0
        config.max_attempts = 3
        delays = []

        allow(Kernel).to receive(:sleep) { |delay| delays << delay }

        expect do
          described_class.with_retry(config) { raise StandardError }
        end.to raise_error(StandardError)

        expect(delays).to eq([0.1, 0.2])
      end

      it 'caps delay at max_delay' do
        config.base_delay = 10.0
        config.backoff_multiplier = 5.0
        config.max_delay = 15.0
        config.max_attempts = 3
        delays = []

        allow(Kernel).to receive(:sleep) { |delay| delays << delay }

        expect do
          described_class.with_retry(config) { raise StandardError }
        end.to raise_error(StandardError)

        expect(delays).to eq([10.0, 15.0])
      end

      it 'calls on_retry callback when provided' do
        callback_calls = []
        config.on_retry = lambda { |error, attempt, delay|
          callback_calls << { error: error.message, attempt: attempt, delay: delay }
        }
        config.max_attempts = 3

        allow(Kernel).to receive(:sleep)

        expect do
          described_class.with_retry(config) { raise StandardError, 'Test error' }
        end.to raise_error(StandardError)

        expect(callback_calls.size).to eq(2)
        expect(callback_calls[0][:error]).to eq('Test error')
        expect(callback_calls[0][:attempt]).to eq(1)
        expect(callback_calls[1][:attempt]).to eq(2)
      end

      it 'respects retry_if condition when provided' do
        attempt_count = 0
        config.retry_if = ->(_error, attempt) { attempt < 2 }
        config.max_attempts = 5

        expect do
          described_class.with_retry(config) do
            attempt_count += 1
            raise StandardError, 'Test error'
          end
        end.to raise_error(StandardError)

        expect(attempt_count).to eq(2)
      end

      it 'does not retry on non-retriable exceptions' do
        config.retry_on_exceptions = [RuntimeError]
        attempt_count = 0

        expect do
          described_class.with_retry(config) do
            attempt_count += 1
            raise ArgumentError, 'Non-retriable error'
          end
        end.to raise_error(ArgumentError)

        expect(attempt_count).to eq(1)
      end
    end
  end

  describe '.configure_element_retry' do
    it 'returns a RetryConfig instance' do
      result = described_class.configure_element_retry
      expect(result).to be_a(described_class::RetryConfig)
    end

    it 'yields config to block when provided' do
      expect do |b|
        described_class.configure_element_retry(&b)
      end.to yield_with_args(instance_of(described_class::RetryConfig))
    end

    it 'allows configuration through block' do
      config = described_class.configure_element_retry do |c|
        c.max_attempts = 5
        c.base_delay = 1.0
      end

      expect(config.max_attempts).to eq(5)
      expect(config.base_delay).to eq(1.0)
    end
  end

  describe '::RetryMethods' do
    let(:test_class) do
      Class.new do
        include Appom::Retry::RetryMethods

        def sample_element
          @sample_element ||= double('element')
        end

        def failing_element
          raise Appom::ElementNotFoundError.new('element', 5)
        end
      end
    end

    let(:instance) { test_class.new }
    let(:mock_element) { double('element') }

    before do
      allow(instance).to receive(:sample_element).and_return(mock_element)
    end

    describe '#find_with_retry' do
      it 'finds element with retry logic' do
        result = instance.find_with_retry(:sample_element)
        expect(result).to eq(mock_element)
      end

      it 'retries on element finding failures' do
        call_count = 0
        allow(instance).to receive(:failing_element) do
          call_count += 1
          raise Appom::ElementNotFoundError.new('element', 5) if call_count < 3

          mock_element
        end

        result = instance.find_with_retry(:failing_element, max_attempts: 3)
        expect(result).to eq(mock_element)
        expect(call_count).to eq(3)
      end

      it 'passes retry options to build_retry_config' do
        options = { max_attempts: 5, base_delay: 1.0 }
        expect(instance).to receive(:build_retry_config).with(options).and_call_original

        instance.find_with_retry(:sample_element, **options)
      end
    end

    describe '#interact_with_retry' do
      before do
        allow(mock_element).to receive(:tap)
        allow(mock_element).to receive(:clear)
        allow(mock_element).to receive(:send_keys)
      end

      it 'performs tap action by default' do
        expect(mock_element).to receive(:tap)

        result = instance.interact_with_retry(:sample_element)
        expect(result).to eq(mock_element)
      end

      it 'performs specified action' do
        expect(mock_element).to receive(:clear)

        instance.interact_with_retry(:sample_element, :clear)
      end

      it 'performs click action (alias for tap)' do
        expect(mock_element).to receive(:tap)

        instance.interact_with_retry(:sample_element, :click)
      end

      it 'performs send_keys action with text' do
        expect(mock_element).to receive(:send_keys).with('test text')

        instance.interact_with_retry(:sample_element, :send_keys, text: 'test text')
      end

      it 'performs custom action' do
        expect(mock_element).to receive(:custom_method)

        instance.interact_with_retry(:sample_element, :custom_method)
      end

      it 'retries on interaction failures' do
        call_count = 0
        allow(mock_element).to receive(:tap) do
          call_count += 1
          raise StandardError, 'Tap failed' if call_count < 3
        end

        result = instance.interact_with_retry(:sample_element, :tap, max_attempts: 3)
        expect(result).to eq(mock_element)
        expect(call_count).to eq(3)
      end
    end

    describe '#get_text_with_retry' do
      before do
        allow(mock_element).to receive(:text).and_return('sample text')
      end

      it 'returns element text' do
        result = instance.get_text_with_retry(:sample_element)
        expect(result).to eq('sample text')
      end

      it 'validates text when validation block provided' do
        validation = ->(text) { text.include?('sample') }

        result = instance.get_text_with_retry(:sample_element, validate_text: validation)
        expect(result).to eq('sample text')
      end

      it 'retries when text validation fails' do
        call_count = 0
        allow(mock_element).to receive(:text) do
          call_count += 1
          call_count < 3 ? 'invalid' : 'valid text'
        end

        validation = ->(text) { text == 'valid text' }

        result = instance.get_text_with_retry(:sample_element,
                                              validate_text: validation,
                                              max_attempts: 3,)
        expect(result).to eq('valid text')
        expect(call_count).to eq(3)
      end

      it 'raises ElementStateError when text validation fails' do
        validation = ->(_text) { false }

        expect do
          instance.get_text_with_retry(:sample_element,
                                       validate_text: validation,
                                       max_attempts: 1,)
        end.to raise_error(Appom::ElementStateError)
      end
    end

    describe '#wait_for_state_with_retry' do
      before do
        allow(mock_element).to receive_messages(displayed?: true, enabled?: true)
      end

      context 'with displayed state' do
        it 'succeeds when element is displayed' do
          result = instance.wait_for_state_with_retry(:sample_element, :displayed)
          expect(result).to eq(mock_element)
        end

        it 'raises ElementStateError when element is not displayed' do
          allow(mock_element).to receive(:displayed?).and_return(false)

          expect do
            instance.wait_for_state_with_retry(:sample_element, :displayed, max_attempts: 1)
          end.to raise_error(Appom::ElementStateError)
        end
      end

      context 'with enabled state' do
        it 'succeeds when element is enabled' do
          result = instance.wait_for_state_with_retry(:sample_element, :enabled)
          expect(result).to eq(mock_element)
        end

        it 'raises ElementStateError when element is not enabled' do
          allow(mock_element).to receive(:enabled?).and_return(false)

          expect do
            instance.wait_for_state_with_retry(:sample_element, :enabled, max_attempts: 1)
          end.to raise_error(Appom::ElementStateError)
        end
      end

      context 'with not_displayed state' do
        it 'succeeds when element is not displayed' do
          allow(mock_element).to receive(:displayed?).and_return(false)

          result = instance.wait_for_state_with_retry(:sample_element, :not_displayed)
          expect(result).to eq(mock_element)
        end

        it 'raises ElementStateError when element is displayed' do
          expect do
            instance.wait_for_state_with_retry(:sample_element, :not_displayed, max_attempts: 1)
          end.to raise_error(Appom::ElementStateError)
        end
      end

      context 'with unknown state' do
        it 'raises ConfigurationError' do
          expect do
            instance.wait_for_state_with_retry(:sample_element, :unknown_state, max_attempts: 1)
          end.to raise_error(Appom::ConfigurationError)
        end
      end

      it 'retries state checking' do
        call_count = 0
        allow(mock_element).to receive(:displayed?) do
          call_count += 1
          call_count >= 3
        end

        result = instance.wait_for_state_with_retry(:sample_element, :displayed, max_attempts: 3)
        expect(result).to eq(mock_element)
        expect(call_count).to eq(3)
      end
    end

    describe '#build_retry_config' do
      it 'builds config with default values' do
        config = instance.send(:build_retry_config, {})

        expect(config.max_attempts).to eq(3)
        expect(config.base_delay).to eq(0.5)
        expect(config.backoff_multiplier).to eq(1.5)
        expect(config.max_delay).to eq(30)
      end

      it 'builds config with custom values' do
        options = {
          max_attempts: 5,
          base_delay: 1.0,
          backoff_multiplier: 2.0,
          max_delay: 60,
        }

        config = instance.send(:build_retry_config, options)

        expect(config.max_attempts).to eq(5)
        expect(config.base_delay).to eq(1.0)
        expect(config.backoff_multiplier).to eq(2.0)
        expect(config.max_delay).to eq(60)
      end

      it 'sets retry_on exceptions when specified' do
        config = instance.send(:build_retry_config, { retry_on: RuntimeError })
        expect(config.retry_on_exceptions).to eq([RuntimeError])
      end

      it 'sets retry_if condition when specified' do
        condition = ->(_e, _attempt) { true }
        config = instance.send(:build_retry_config, { retry_if: condition })
        expect(config.retry_if).to eq(condition)
      end

      it 'sets custom on_retry callback when specified' do
        callback = ->(_e, _attempt, _delay) {}
        config = instance.send(:build_retry_config, { on_retry: callback })
        expect(config.on_retry).to eq(callback)
      end

      it 'sets default logging callback when log_warn is available' do
        allow(instance).to receive(:log_warn)
        allow(instance).to receive(:respond_to?).with(:log_warn).and_return(true)

        config = instance.send(:build_retry_config, {})
        expect(config.on_retry).to be_a(Proc)
      end
    end
  end
end
