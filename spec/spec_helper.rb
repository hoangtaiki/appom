# frozen_string_literal: true

# SimpleCov with enhanced configuration
require 'simplecov'

# Only run coverage in CI or when explicitly requested
if ENV['CI'] || ENV['COVERAGE']
  require 'simplecov-cobertura' if ENV['CI']

  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
    add_filter '/coverage/'

    # Group coverage results for better reporting
    add_group 'Core', 'lib/appom.rb'
    add_group 'Page Objects', 'lib/appom/page.rb'
    add_group 'Elements', 'lib/appom/element_'
    add_group 'Helpers', 'lib/appom/helpers.rb'
    add_group 'Configuration', 'lib/appom/configuration.rb'
    add_group 'Advanced', ['lib/appom/performance.rb', 'lib/appom/visual.rb', 'lib/appom/smart_wait.rb']

    coverage_dir 'coverage'
    minimum_coverage 85 # Increased for better quality
    minimum_coverage_by_file 80

    # Configure formatters based on environment
    if ENV['CI']
      formatter SimpleCov::Formatter::MultiFormatter.new([
                                                           SimpleCov::Formatter::HTMLFormatter,
                                                           SimpleCov::Formatter::CoberturaFormatter, # For Codecov
                                                         ])
    else
      formatter SimpleCov::Formatter::HTMLFormatter
    end
  end
end

require 'bundler/setup'
require 'webmock/rspec'
require 'appom'

# Disable external HTTP requests during tests
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Mock Appium driver for tests
  config.before do
    mock_driver = double('appium_driver')
    allow(mock_driver).to receive(:start_driver)
    allow(mock_driver).to receive(:reset)
    allow(mock_driver).to receive(:driver_quit)
    allow(mock_driver).to receive(:find_element)
    allow(mock_driver).to receive(:find_elements).and_return([])

    Appom.driver = mock_driver
    Appom.max_wait_time = 1 # Use short timeout for tests

    # Reset Phase 2 systems before each test (disabled to prevent infinite logging)
    # Appom::Performance.reset! if defined?(Appom::Performance)
    # Appom::ElementState.clear! if defined?(Appom::ElementState)
    # Appom::Visual.clear_results! if defined?(Appom::Visual)
    # Appom::ElementCache.clear_cache if defined?(Appom::ElementCache)

    # Set test-friendly configuration
    if defined?(Appom::Configuration)
      Appom::Configuration.set('performance.monitoring_enabled', true)
      Appom::Configuration.set('element_state.tracking_enabled', false) # Disabled by default in tests
      Appom::Configuration.set('visual.threshold', 0.01)
      Appom::Configuration.set('element_cache.max_size', 10)
      Appom::Configuration.set('element_cache.ttl', 60)
    end
  end

  config.after do
    Appom.driver = nil

    # Clean up Phase 2 systems after each test (disabled to prevent infinite logging)
    # Appom::Performance.reset! if defined?(Appom::Performance)
    # Appom::ElementState.clear! if defined?(Appom::ElementState)
    # Appom::Visual.clear_results! if defined?(Appom::Visual)
    # Appom::ElementCache.clear_cache if defined?(Appom::ElementCache)

    # Clean up any test files created during visual testing
    Dir.glob('spec/fixtures/**/*').each do |file|
      File.delete(file) if File.file?(file)
    end
  end

  # Configure slow test filter
  config.filter_run_excluding slow: true unless ENV['RUN_SLOW_TESTS'] == 'true'
end
