# frozen_string_literal: true

# Performance monitoring for Appom automation framework
# Tracks and analyzes performance metrics for test execution
module Appom::Performance
  # Performance monitoring and metrics collection
  class Monitor
    include Appom::Logging

    attr_reader :metrics, :started_at

    def initialize
      @metrics = {}
      @started_at = Time.now
      @current_operations = {}
      reset_session_metrics
    end

    # Start timing an operation
    def start_timing(operation_name, context = {})
      operation_id = generate_operation_id
      @current_operations[operation_id] = {
        name: operation_name,
        start_time: Time.now,
        context: context,
      }

      log_debug("Started timing: #{operation_name}", context)
      operation_id
    end

    # End timing an operation
    def end_timing(operation_id, success: true, additional_context: {})
      operation = @current_operations.delete(operation_id)
      return unless operation

      duration = Time.now - operation[:start_time]

      record_metric(
        operation[:name],
        duration,
        success: success,
        context: operation[:context].merge(additional_context),
      )

      log_debug("Completed timing: #{operation[:name]} (#{(duration * 1000).round(2)}ms)")
      duration
    end

    # Time a block of code
    def time_operation(operation_name, context = {})
      operation_id = start_timing(operation_name, context)
      Time.now
      success = true
      result = nil

      begin
        result = yield
      rescue StandardError => e
        success = false
        raise e
      ensure
        end_timing(operation_id, success: success, additional_context: {
                     exception: success ? nil : e&.class&.name,
                   },)
      end

      result
    end

    # Record a metric manually
    def record_metric(name, duration, success: true, context: {})
      @metrics[name] ||= initialize_metric(name)
      metric = @metrics[name]

      metric[:total_calls] += 1
      metric[:total_duration] += duration
      metric[:successful_calls] += 1 if success
      metric[:failed_calls] += 1 unless success

      # Update min/max
      metric[:min_duration] = [metric[:min_duration], duration].min
      metric[:max_duration] = [metric[:max_duration], duration].max

      # Calculate rolling averages (last 10 calls)
      metric[:recent_durations] << duration
      metric[:recent_durations] = metric[:recent_durations].last(10)

      # Store context for analysis
      metric[:contexts] << context.merge(success: success, duration: duration)
      metric[:contexts] = metric[:contexts].last(50) # Keep last 50 contexts

      # Update percentiles for larger samples
      return unless (metric[:total_calls] % 10).zero?

      update_percentiles(metric)
    end

    # Get performance statistics
    def stats(operation_name = nil)
      if operation_name
        calculate_stats(@metrics[operation_name]) if @metrics[operation_name]
      else
        @metrics.transform_values { |metric| calculate_stats(metric) }
      end
    end

    # Get performance summary
    def summary
      total_operations = @metrics.values.sum { |m| m[:total_calls] }
      total_duration = @metrics.values.sum { |m| m[:total_duration] }

      {
        session_duration: Time.now - @started_at,
        total_operations: total_operations,
        total_duration: total_duration,
        average_operation_time: total_operations.positive? ? total_duration / total_operations : 0,
        operations_per_second: total_operations / (Time.now - @started_at),
        slowest_operations: slowest_operations(5),
        most_frequent_operations: most_frequent_operations(5),
        success_rate: calculate_overall_success_rate,
      }
    end

    # Get slowest operations
    def slowest_operations(limit = 10)
      @metrics.map do |name, metric|
        {
          name: name,
          max_duration: metric[:max_duration],
          avg_duration: metric[:total_duration] / metric[:total_calls],
          total_calls: metric[:total_calls],
        }
      end.sort_by { |op| -op[:max_duration] }.first(limit)
    end

    # Get most frequent operations
    def most_frequent_operations(limit = 10)
      @metrics.map do |name, metric|
        {
          name: name,
          total_calls: metric[:total_calls],
          avg_duration: metric[:total_duration] / metric[:total_calls],
          success_rate: (metric[:successful_calls].to_f / metric[:total_calls] * 100).round(2),
        }
      end.sort_by { |op| -op[:total_calls] }.first(limit)
    end

    # Export metrics to file
    def export_metrics(format: :json, file_path: nil)
      file_path ||= "appom_metrics_#{Time.now.strftime('%Y%m%d_%H%M%S')}.#{format}"

      data = {
        exported_at: Time.now,
        session_started: @started_at,
        summary: summary,
        detailed_metrics: stats,
      }

      case format
      when :json
        File.write(file_path, JSON.pretty_generate(data))
      when :yaml
        File.write(file_path, YAML.dump(data))
      when :csv
        export_to_csv(file_path, data)
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end

      log_info("Performance metrics exported to #{file_path}")
      file_path
    end

    # Reset all metrics
    def reset!
      @metrics.clear
      @started_at = Time.now
      @current_operations.clear
      reset_session_metrics
      log_info('Performance metrics reset')
    end

    # Check for performance regressions
    def check_regressions(baseline_file, threshold_percent = 20)
      return {} unless File.exist?(baseline_file)

      baseline = load_baseline(baseline_file)
      regressions = {}

      @metrics.each do |name, current_metric|
        baseline_metric = baseline[name]
        next unless baseline_metric

        current_avg = current_metric[:total_duration] / current_metric[:total_calls]
        baseline_avg = baseline_metric['avg_duration'] || baseline_metric[:avg_duration]

        next unless current_avg > baseline_avg * (1 + (threshold_percent / 100.0))

        regression_percent = ((current_avg - baseline_avg) / baseline_avg * 100).round(2)
        regressions[name] = {
          current_avg: current_avg,
          baseline_avg: baseline_avg,
          regression_percent: regression_percent,
        }
      end

      regressions
    end

    private

    def reset_session_metrics
      @session_metrics = {
        element_finds: 0,
        wait_operations: 0,
        interactions: 0,
        screenshots: 0,
      }
    end

    def generate_operation_id
      "#{Time.now.to_f}_#{rand(1000)}"
    end

    def initialize_metric(name)
      {
        name: name,
        total_calls: 0,
        successful_calls: 0,
        failed_calls: 0,
        total_duration: 0.0,
        min_duration: Float::INFINITY,
        max_duration: 0.0,
        recent_durations: [],
        contexts: [],
        percentiles: {},
      }
    end

    def calculate_stats(metric)
      return {} unless metric && metric[:total_calls].positive?

      {
        name: metric[:name],
        total_calls: metric[:total_calls],
        successful_calls: metric[:successful_calls],
        failed_calls: metric[:failed_calls],
        success_rate: (metric[:successful_calls].to_f / metric[:total_calls] * 100).round(2),
        total_duration: metric[:total_duration],
        avg_duration: metric[:total_duration] / metric[:total_calls],
        min_duration: metric[:min_duration] == Float::INFINITY ? 0 : metric[:min_duration],
        max_duration: metric[:max_duration],
        recent_avg: metric[:recent_durations].empty? ? 0 : metric[:recent_durations].sum / metric[:recent_durations].size,
        percentiles: metric[:percentiles],
      }
    end

    def update_percentiles(metric)
      all_durations = metric[:contexts].map { |c| c[:duration] }.sort
      return if all_durations.empty?

      metric[:percentiles] = {
        p50: percentile(all_durations, 50),
        p75: percentile(all_durations, 75),
        p90: percentile(all_durations, 90),
        p95: percentile(all_durations, 95),
        p99: percentile(all_durations, 99),
      }
    end

    def percentile(sorted_array, percentile)
      return 0 if sorted_array.empty?

      index = (percentile / 100.0 * (sorted_array.length - 1)).round
      sorted_array[index]
    end

    def calculate_overall_success_rate
      total_calls = @metrics.values.sum { |m| m[:total_calls] }
      return 100.0 if total_calls.zero?

      successful_calls = @metrics.values.sum { |m| m[:successful_calls] }
      (successful_calls.to_f / total_calls * 100).round(2)
    end

    def export_to_csv(file_path, data)
      require 'csv'

      CSV.open(file_path, 'w') do |csv|
        # Headers
        csv << ['Operation', 'Total Calls', 'Success Rate', 'Avg Duration', 'Min Duration', 'Max Duration']

        # Data rows
        data[:detailed_metrics].each do |name, stats|
          csv << [
            name,
            stats[:total_calls],
            stats[:success_rate],
            stats[:avg_duration],
            stats[:min_duration],
            stats[:max_duration],
          ]
        end
      end
    end

    def load_baseline(file_path)
      case File.extname(file_path)
      when '.json'
        JSON.parse(File.read(file_path))['detailed_metrics'] || {}
      when '.yml', '.yaml'
        YAML.load_file(file_path, permitted_classes: [Time])['detailed_metrics'] || {}
      else
        {}
      end
    rescue StandardError => e
      log_error("Failed to load baseline from #{file_path}: #{e.message}")
      {}
    end
  end

  # Performance-aware method wrapper
  module MethodInstrumentation
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    # Class methods for method instrumentation
    module ClassMethods
      # Instrument methods for performance monitoring
      def instrument_method(method_name, operation_name: nil)
        operation_name ||= "#{name}##{method_name}"

        alias_method "#{method_name}_without_instrumentation", method_name

        define_method(method_name) do |*args, &block|
          Appom::Performance.monitor.time_operation(operation_name) do
            send("#{method_name}_without_instrumentation", *args, &block)
          end
        end
      end

      # Instrument all methods matching pattern
      def instrument_methods(pattern, operation_prefix: nil)
        operation_prefix ||= name

        instance_methods(false).grep(pattern).each do |method_name|
          instrument_method(method_name, operation_name: "#{operation_prefix}##{method_name}")
        end
      end
    end
  end

  # Global performance monitor
  class << self
    attr_writer :monitor

    def monitor
      @monitor ||= Monitor.new
    end

    # Convenience methods
    def time_operation(name, context = {}, &)
      monitor.time_operation(name, context, &)
    end

    def record_metric(name, duration, **)
      monitor.record_metric(name, duration, **)
    end

    def stats(operation_name = nil)
      monitor.stats(operation_name)
    end

    def summary
      monitor.summary
    end

    def export_metrics(**)
      monitor.export_metrics(**)
    end

    def reset!
      monitor.reset!
    end

    def check_regressions(baseline_file, threshold_percent = 20)
      monitor.check_regressions(baseline_file, threshold_percent)
    end
  end
end
