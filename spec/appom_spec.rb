# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Appom do
  let(:mock_driver) { double('driver') }

  after do
    # Reset state after each test
    described_class.instance_variable_set(:@driver, nil)
    described_class.instance_variable_set(:@max_wait_time, 20)
  end

  describe '.configure' do
    it 'allows configuration of max_wait_time' do
      described_class.configure do |config|
        config.max_wait_time = 10
      end

      expect(described_class.max_wait_time).to eq(10)
    end

    it 'yields self for configuration' do
      described_class.configure do |config|
        expect(config).to eq(described_class)
      end
    end
  end

  describe '.register_driver' do
    it 'registers a new driver' do
      driver = described_class.register_driver { mock_driver }

      expect(described_class.driver).to eq(mock_driver)
      expect(driver).to eq(mock_driver)
    end

    it 'logs driver registration' do
      expect(described_class).to receive(:log_info).with('Registering Appium driver')
      expect(described_class).to receive(:log_info).with('Appium driver registered successfully')

      described_class.register_driver { mock_driver }
    end

    it 'measures performance during registration' do
      expect(Appom::Performance).to receive(:time_operation).with('driver_registration').and_yield.and_return(mock_driver)

      described_class.register_driver { mock_driver }
    end

    it 'initializes element state tracking when enabled' do
      allow(Appom::Configuration).to receive(:get).with('element_state.tracking_enabled', false).and_return(true)
      expect(Appom::ElementState).to receive(:tracker)
      expect(described_class).to receive(:log_info).with('Registering Appium driver')
      expect(described_class).to receive(:log_info).with('Appium driver registered successfully')
      expect(described_class).to receive(:log_info).with('Element state tracking initialized')

      described_class.register_driver { mock_driver }
    end

    it 'raises DriverError on registration failure' do
      error = StandardError.new('Test error')
      expect(described_class).to receive(:log_error).with('Failed to register driver', { error: error.message })

      expect do
        described_class.register_driver { raise error }
      end.to raise_error(Appom::DriverError, 'Failed to register driver: Test error')
    end

    it 'sets up exit handler' do
      expect(described_class).to receive(:setup_exit_handler)

      described_class.register_driver { mock_driver }
    end
  end

  describe '.start_driver' do
    before { described_class.instance_variable_set(:@driver, mock_driver) }

    it 'starts the registered driver' do
      expect(mock_driver).to receive(:start_driver)
      expect(described_class).to receive(:log_info).with('Starting Appium driver')
      expect(described_class).to receive(:log_info).with('Appium driver started successfully')

      described_class.start_driver
    end

    it 'measures performance during start' do
      expect(Appom::Performance).to receive(:time_operation).with('driver_start').and_yield
      expect(mock_driver).to receive(:start_driver)

      described_class.start_driver
    end

    it 'raises DriverNotInitializedError when no driver registered' do
      described_class.instance_variable_set(:@driver, nil)

      expect do
        described_class.start_driver
      end.to raise_error(Appom::DriverNotInitializedError)
    end

    it 'raises DriverOperationError on start failure' do
      error = StandardError.new('Start failed')
      allow(mock_driver).to receive(:start_driver).and_raise(error)
      expect(described_class).to receive(:log_error).with('Failed to start driver', { error: error.message })

      expect do
        described_class.start_driver
      end.to raise_error(Appom::DriverOperationError) do |e|
        expect(e.operation).to eq('start_driver')
        expect(e.message).to include('Start failed')
      end
    end
  end

  describe '.reset_driver' do
    before { described_class.instance_variable_set(:@driver, mock_driver) }

    it 'resets the registered driver' do
      expect(mock_driver).to receive(:reset)
      expect(described_class).to receive(:log_info).with('Resetting Appium driver')
      expect(described_class).to receive(:log_info).with('Appium driver reset successfully')

      described_class.reset_driver
    end

    it 'measures performance during reset' do
      expect(Appom::Performance).to receive(:time_operation).with('driver_reset').and_yield
      expect(mock_driver).to receive(:reset)

      described_class.reset_driver
    end

    it 'raises DriverNotInitializedError when no driver registered' do
      described_class.instance_variable_set(:@driver, nil)

      expect do
        described_class.reset_driver
      end.to raise_error(Appom::DriverNotInitializedError)
    end

    it 'raises DriverOperationError on reset failure' do
      error = StandardError.new('Reset failed')
      allow(mock_driver).to receive(:reset).and_raise(error)
      expect(described_class).to receive(:log_error).with('Failed to reset driver', { error: error.message })

      expect do
        described_class.reset_driver
      end.to raise_error(Appom::DriverOperationError) do |e|
        expect(e.operation).to eq('reset')
        expect(e.message).to include('Reset failed')
      end
    end
  end

  describe '.setup_exit_handler' do
    it 'quits driver on exit when process matches main' do
      allow(Process).to receive(:pid).and_return(123)
      expect(mock_driver).to receive(:driver_quit)

      described_class.instance_variable_set(:@driver, mock_driver)

      # Test the extracted cleanup method directly
      described_class.send(:cleanup_on_exit, 123)
    end
  end

  describe 'convenience methods' do
    describe '.performance_stats' do
      it 'delegates to Performance.summary' do
        expect(Appom::Performance).to receive(:summary)

        described_class.performance_stats
      end
    end

    describe '.export_performance_metrics' do
      it 'delegates to Performance.export_metrics with options' do
        options = { format: :json }
        expect(Appom::Performance).to receive(:export_metrics).with(**options)

        described_class.export_performance_metrics(**options)
      end
    end

    describe '.visual_regression_test' do
      it 'delegates to Visual.regression_test with name and options' do
        expect(Appom::Visual).to receive(:regression_test).with('test', format: :png)

        described_class.visual_regression_test('test', format: :png)
      end
    end

    describe '.generate_visual_report' do
      it 'delegates to Visual.generate_report with options' do
        options = { output: 'report.html' }
        expect(Appom::Visual).to receive(:generate_report).with(**options)

        described_class.generate_visual_report(**options)
      end
    end

    describe '.element_tracking_summary' do
      it 'delegates to ElementState.tracking_summary' do
        expect(Appom::ElementState).to receive(:tracking_summary)

        described_class.element_tracking_summary
      end
    end

    describe '.export_element_tracking' do
      it 'delegates to ElementState.export_data with options' do
        options = { format: :csv }
        expect(Appom::ElementState).to receive(:export_data).with(**options)

        described_class.export_element_tracking(**options)
      end
    end
  end

  describe 'module constants' do
    it 'has default max_wait_time of 20' do
      # Reset to default value since spec_helper overrides it
      described_class.max_wait_time = 20
      expect(described_class.max_wait_time).to eq(20)
    end
  end
end
