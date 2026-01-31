require 'spec_helper'

RSpec.describe Appom::Performance do
  let(:monitor) { Appom::Performance::Monitor.new }
  
  describe Appom::Performance::Monitor do
    describe '#initialize' do
      it 'initializes with empty metrics' do
        expect(monitor.metrics).to be_empty
        expect(monitor.started_at).to be_a(Time)
      end
    end

    describe '#time_operation' do
      it 'times a block execution' do
        result = monitor.time_operation('test_operation') do
          sleep(0.1)
          'test_result'
        end
        
        expect(result).to eq('test_result')
        expect(monitor.metrics['test_operation']).to be_a(Hash)
        expect(monitor.metrics['test_operation'][:total_calls]).to eq(1)
        expect(monitor.metrics['test_operation'][:total_duration]).to be > 0.1
      end

      it 'records failed operations' do
        expect do
          monitor.time_operation('failing_operation') do
            raise StandardError, 'test error'
          end
        end.to raise_error(StandardError, 'test error')
        
        metric = monitor.metrics['failing_operation']
        expect(metric[:failed_calls]).to eq(1)
        expect(metric[:successful_calls]).to eq(0)
      end
    end

    describe '#record_metric' do
      it 'records a metric with duration' do
        monitor.record_metric('manual_operation', 0.5, success: true)
        
        metric = monitor.metrics['manual_operation']
        expect(metric[:total_calls]).to eq(1)
        expect(metric[:successful_calls]).to eq(1)
        expect(metric[:total_duration]).to eq(0.5)
        expect(metric[:min_duration]).to eq(0.5)
        expect(metric[:max_duration]).to eq(0.5)
      end

      it 'updates min and max durations' do
        monitor.record_metric('varying_operation', 0.3, success: true)
        monitor.record_metric('varying_operation', 0.7, success: true)
        monitor.record_metric('varying_operation', 0.1, success: true)
        
        metric = monitor.metrics['varying_operation']
        expect(metric[:min_duration]).to eq(0.1)
        expect(metric[:max_duration]).to eq(0.7)
        expect(metric[:total_calls]).to eq(3)
      end
    end

    describe '#stats' do
      before do
        monitor.record_metric('test_op', 0.2, success: true)
        monitor.record_metric('test_op', 0.4, success: true)
        monitor.record_metric('test_op', 0.1, success: false)
      end

      it 'calculates comprehensive statistics' do
        stats = monitor.stats('test_op')
        
        expect(stats[:total_calls]).to eq(3)
        expect(stats[:successful_calls]).to eq(2)
        expect(stats[:failed_calls]).to eq(1)
        expect(stats[:success_rate]).to eq(66.67)
        expect(stats[:avg_duration]).to be_within(0.01).of(0.233)
      end

      it 'returns stats for all operations when no name given' do
        stats = monitor.stats
        expect(stats).to have_key('test_op')
        expect(stats['test_op']).to be_a(Hash)
      end
    end

    describe '#summary' do
      before do
        monitor.record_metric('op1', 0.1, success: true)
        monitor.record_metric('op2', 0.2, success: true)
        monitor.record_metric('op1', 0.3, success: false)
      end

      it 'provides session summary' do
        summary = monitor.summary
        
        expect(summary[:total_operations]).to eq(3)
        expect(summary[:total_duration]).to be_within(0.01).of(0.6)
        expect(summary[:success_rate]).to eq(66.67)
        expect(summary[:operations_per_second]).to be > 0
      end
    end

    describe '#export_metrics' do
      before do
        monitor.record_metric('export_test', 0.1, success: true)
      end

      it 'exports metrics to JSON' do
        file_path = monitor.export_metrics(format: :json, file_path: 'test_metrics.json')
        
        expect(File.exist?(file_path)).to be true
        data = JSON.parse(File.read(file_path))
        expect(data['detailed_metrics']).to have_key('export_test')
        
        File.delete(file_path)
      end

      it 'exports metrics to YAML' do
        file_path = monitor.export_metrics(format: :yaml, file_path: 'test_metrics.yml')
        
        expect(File.exist?(file_path)).to be true
        data = YAML.load_file(file_path, permitted_classes: [Time, Symbol])
        
        # Handle both string and symbol keys
        detailed_metrics = data['detailed_metrics'] || data[:detailed_metrics]
        expect(detailed_metrics).to be_truthy
        expect(detailed_metrics).to have_key('export_test')
        
        File.delete(file_path)
      end
    end

    describe '#check_regressions' do
      let(:baseline_file) { 'test_baseline.json' }
      
      before do
        baseline_data = {
          'detailed_metrics' => {
            'test_operation' => { 'avg_duration' => 0.1 }
          }
        }
        File.write(baseline_file, JSON.pretty_generate(baseline_data))
        
        monitor.record_metric('test_operation', 0.15, success: true)
      end

      after do
        File.delete(baseline_file) if File.exist?(baseline_file)
      end

      it 'detects performance regressions' do
        regressions = monitor.check_regressions(baseline_file, 20)
        
        expect(regressions).to have_key('test_operation')
        expect(regressions['test_operation'][:regression_percent]).to eq(50.0)
      end
    end

    describe '#reset!' do
      before do
        monitor.record_metric('test', 0.1, success: true)
      end

      it 'clears all metrics and resets timer' do
        original_start = monitor.started_at
        sleep(0.01)
        
        monitor.reset!
        
        expect(monitor.metrics).to be_empty
        expect(monitor.started_at).to be > original_start
      end
    end
  end

  describe 'Global Performance module' do
    before { Appom::Performance.reset! }
    after { Appom::Performance.reset! }

    describe '.time_operation' do
      it 'uses the global monitor' do
        result = Appom::Performance.time_operation('global_test') do
          'result'
        end
        
        expect(result).to eq('result')
        expect(Appom::Performance.stats).to have_key('global_test')
      end
    end

    describe '.summary' do
      it 'returns global performance summary' do
        Appom::Performance.record_metric('test', 0.1, success: true)
        summary = Appom::Performance.summary
        
        expect(summary[:total_operations]).to eq(1)
      end
    end

    describe '.export_metrics' do
      it 'exports global metrics' do
        Appom::Performance.record_metric('export', 0.1, success: true)
        file_path = Appom::Performance.export_metrics(format: :json, file_path: 'global_test.json')
        
        expect(File.exist?(file_path)).to be true
        File.delete(file_path)
      end
    end
  end

  describe Appom::Performance::MethodInstrumentation do
    let(:test_class) do
      Class.new do
        include Appom::Performance::MethodInstrumentation
        
        def test_method
          'test_result'
        end
        
        def slow_method
          sleep(0.01)
          'slow_result'
        end
        
        instrument_method :test_method
        instrument_method :slow_method, operation_name: 'custom_slow_operation'
      end
    end

    before { Appom::Performance.reset! }
    after { Appom::Performance.reset! }

    it 'instruments methods for performance monitoring' do
      instance = test_class.new
      result = instance.test_method
      
      expect(result).to eq('test_result')
      stats = Appom::Performance.stats
      expect(stats.keys).to include(a_string_matching(/test_method/))
    end

    it 'allows custom operation names' do
      instance = test_class.new
      result = instance.slow_method
      
      expect(result).to eq('slow_result')
      stats = Appom::Performance.stats
      expect(stats).to have_key('custom_slow_operation')
    end
  end
end