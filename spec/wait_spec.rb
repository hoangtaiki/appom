# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Appom::Wait do
  let(:short_wait) { described_class.new(timeout: 1, interval: 0.1) }
  let(:default_wait) { described_class.new }

  describe '#initialize' do
    it 'accepts timeout and interval options' do
      wait = described_class.new(timeout: 10, interval: 0.5)
      expect(wait.instance_variable_get(:@timeout)).to eq(10)
      expect(wait.instance_variable_get(:@interval)).to eq(0.5)
    end

    it 'uses default timeout when not specified' do
      wait = described_class.new
      expect(wait.instance_variable_get(:@timeout)).to eq(described_class::DEFAULT_TIMEOUT)
    end

    it 'uses default interval when not specified' do
      wait = described_class.new
      expect(wait.instance_variable_get(:@interval)).to eq(described_class::DEFAULT_INTERVAL)
    end

    it 'allows custom timeout with default interval' do
      wait = described_class.new(timeout: 20)
      expect(wait.instance_variable_get(:@timeout)).to eq(20)
      expect(wait.instance_variable_get(:@interval)).to eq(described_class::DEFAULT_INTERVAL)
    end

    it 'allows custom interval with default timeout' do
      wait = described_class.new(interval: 1.0)
      expect(wait.instance_variable_get(:@timeout)).to eq(described_class::DEFAULT_TIMEOUT)
      expect(wait.instance_variable_get(:@interval)).to eq(1.0)
    end
  end

  describe '#until' do
    context 'when condition becomes true immediately' do
      it 'returns the result immediately' do
        result = short_wait.until { 'success' }
        expect(result).to eq('success')
      end

      it 'logs wait start and end' do
        expect(short_wait).to receive(:log_wait_start).with('custom condition', 1)
        expect(short_wait).to receive(:log_wait_end).with('custom condition', anything, true)

        short_wait.until { true }
      end
    end

    context 'when condition becomes true after some time' do
      it 'returns the result when condition becomes true' do
        call_count = 0
        result = short_wait.until do
          call_count += 1
          call_count >= 3 ? 'delayed success' : false
        end

        expect(result).to eq('delayed success')
        expect(call_count).to eq(3)
      end

      it 'sleeps between attempts' do
        call_count = 0
        expect(short_wait).to receive(:sleep).with(0.1).at_least(:once)

        short_wait.until do
          call_count += 1
          call_count >= 3
        end
      end

      it 'logs successful wait with duration' do
        expect(short_wait).to receive(:log_wait_start).with('custom condition', 1)
        expect(short_wait).to receive(:log_wait_end).with('custom condition', anything, true)

        call_count = 0
        short_wait.until do
          call_count += 1
          call_count >= 2
        end
      end
    end

    context 'when condition never becomes true' do
      it 'raises WaitError after timeout' do
        expect do
          short_wait.until { false }
        end.to raise_error(Appom::WaitError) do |error|
          expect(error.timeout).to eq(1)
          expect(error.message).to include('condition')
        end
      end

      it 'logs failed wait with duration' do
        expect(short_wait).to receive(:log_wait_start).with('custom condition', 1)
        expect(short_wait).to receive(:log_wait_end).with('custom condition', anything, false)

        expect { short_wait.until { false } }.to raise_error(Appom::WaitError)
      end

      it 'includes error message in WaitError when block raises exceptions' do
        expect do
          short_wait.until { raise StandardError, 'test error' }
        end.to raise_error(Appom::WaitError) do |error|
          expect(error.message).to include('test error')
        end
      end
    end

    context 'when block raises exceptions' do
      it 'continues waiting through exceptions' do
        call_count = 0
        result = short_wait.until do
          call_count += 1
          raise StandardError, 'temporary error' if call_count < 3

          'success after errors'
        end

        expect(result).to eq('success after errors')
        expect(call_count).to eq(3)
      end

      it 'raises the last exception if timeout is reached' do
        expect do
          short_wait.until { raise ArgumentError, 'persistent error' }
        end.to raise_error(ArgumentError, 'persistent error')
      end

      it 'raises WaitError if no exceptions occurred but condition never true' do
        expect do
          short_wait.until { nil }
        end.to raise_error(Appom::WaitError)
      end

      it 'prioritizes raising exceptions over WaitError' do
        call_count = 0
        expect do
          short_wait.until do
            call_count += 1
            raise 'error on second attempt' unless call_count == 1

            false # First attempt returns false
          end
        end.to raise_error(RuntimeError, 'error on second attempt')
      end
    end

    context 'with different truthy/falsy values' do
      it 'treats truthy values as success' do
        ['string', 1, [], {}].each do |truthy_value|
          result = short_wait.until { truthy_value }
          expect(result).to eq(truthy_value)
        end
      end

      it 'treats falsy values as failure' do
        [false, nil].each do |falsy_value|
          expect do
            short_wait.until { falsy_value }
          end.to raise_error(Appom::WaitError)
        end
      end
    end

    context 'with different timeout values' do
      it 'respects custom timeout' do
        quick_wait = described_class.new(timeout: 0.2, interval: 0.05)
        start_time = Time.now

        expect do
          quick_wait.until { false }
        end.to raise_error(Appom::WaitError)

        elapsed = Time.now - start_time
        expect(elapsed).to be >= 0.2
        expect(elapsed).to be < 0.5 # Should not wait much longer than timeout
      end
    end

    context 'with different interval values' do
      it 'respects custom interval' do
        intervals = []
        allow(short_wait).to receive(:sleep) do |interval|
          intervals << interval
          # Don't actually sleep to speed up test
        end

        expect do
          short_wait.until { false }
        end.to raise_error(Appom::WaitError)

        expect(intervals).to all(eq(0.1))
      end
    end
  end

  describe 'constants' do
    it 'defines DEFAULT_TIMEOUT' do
      expect(described_class::DEFAULT_TIMEOUT).to eq(5)
    end

    it 'defines DEFAULT_INTERVAL' do
      expect(described_class::DEFAULT_INTERVAL).to eq(0.25)
    end
  end

  describe 'includes Logging module' do
    it 'includes the Logging module' do
      expect(described_class.ancestors).to include(Appom::Logging)
    end

    it 'can access logging methods' do
      expect(short_wait).to respond_to(:log_wait_start)
      expect(short_wait).to respond_to(:log_wait_end)
    end
  end

  describe 'integration scenarios' do
    context 'with element finding simulation' do
      it 'waits for element to appear' do
        elements = [nil, nil, 'found_element']
        index = 0

        result = short_wait.until do
          element = elements[index]
          index += 1
          element
        end

        expect(result).to eq('found_element')
      end
    end

    context 'with state change simulation' do
      let(:element) { double('element') }

      it 'waits for element state to change' do
        states = [false, false, true]
        index = 0

        allow(element).to receive(:displayed?) do
          state = states[index]
          index += 1
          state
        end

        result = short_wait.until { element.displayed? }
        expect(result).to be(true)
      end
    end

    context 'with intermittent failures' do
      it 'handles temporary element access issues' do
        attempts = 0
        element = double('element')

        allow(element).to receive(:text) do
          attempts += 1
          raise Selenium::WebDriver::Error::StaleElementReferenceError if attempts < 3

          'stable text'
        end

        result = short_wait.until do
          element.text
        rescue Selenium::WebDriver::Error::StaleElementReferenceError
          false # Continue waiting on stale element errors
        end

        expect(result).to eq('stable text')
      end
    end
  end
end
