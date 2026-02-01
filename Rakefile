# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

# Run only fast tests by default
RSpec::Core::RakeTask.new(:spec_fast) do |task|
  task.rspec_opts = '--tag ~slow'
end

# Run all tests including slow ones
RSpec::Core::RakeTask.new(:spec_all) do |task|
  task.rspec_opts = '--tag ~skip'
end

# Run tests with coverage
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['spec'].invoke
end

# Phase 2 specific test tasks
namespace :spec do
  desc 'Run performance monitoring tests'
  RSpec::Core::RakeTask.new(:performance) do |task|
    task.pattern = 'spec/performance_spec.rb'
  end

  desc 'Run element state tracking tests'
  RSpec::Core::RakeTask.new(:element_state) do |task|
    task.pattern = 'spec/element_state_spec.rb'
  end

  desc 'Run visual testing tests'
  RSpec::Core::RakeTask.new(:visual) do |task|
    task.pattern = 'spec/visual_spec.rb'
  end

  desc 'Run element caching tests'
  RSpec::Core::RakeTask.new(:cache) do |task|
    task.pattern = 'spec/element_cache_spec.rb'
  end

  desc 'Run smart wait tests'
  RSpec::Core::RakeTask.new(:smart_wait) do |task|
    task.pattern = 'spec/smart_wait_spec.rb'
  end

  desc 'Run integration tests'
  RSpec::Core::RakeTask.new(:integration) do |task|
    task.pattern = 'spec/integration_spec.rb'
  end

  desc 'Run all Phase 2 tests'
  task phase2: %i[performance element_state visual cache smart_wait integration]
end

# Lint and format tasks
begin
  require 'rubocop/rake_task'

  RuboCop::RakeTask.new(:rubocop) do |task|
    task.options = ['--display-cop-names']
  end

  RuboCop::RakeTask.new('rubocop:auto_correct') do |task|
    task.options = ['--auto-correct']
  end
rescue LoadError
  # RuboCop not available
end

# Default task
task default: :spec_fast

# Development setup task
task :setup do
  puts 'Setting up development environment...'

  # Create necessary directories
  %w[spec/fixtures spec/fixtures/baselines spec/fixtures/results].each do |dir|
    FileUtils.mkdir_p(dir)
    puts "Created directory: #{dir}"
  end

  puts 'Development environment ready!'
end

# Cleanup task
task :clean do
  puts 'Cleaning up...'

  # Remove coverage files
  FileUtils.rm_rf('coverage')

  # Remove test artifacts
  FileUtils.rm_rf('spec/fixtures')

  # Remove temporary files
  Dir.glob('*_metrics*.{json,yml,csv}').each { |f| File.delete(f) }
  Dir.glob('*_tracking*.{json,yml}').each { |f| File.delete(f) }
  Dir.glob('*_report*.html').each { |f| File.delete(f) }

  puts 'Cleanup complete!'
end

desc 'Run quick smoke test'
task :smoke do
  puts 'Running smoke test...'

  # Test basic loading
  begin
    require_relative 'lib/appom'
    puts '✓ Basic loading works'
  rescue StandardError => e
    puts "✗ Basic loading failed: #{e.message}"
    exit 1
  end

  # Test Phase 2 modules
  phase2_modules = %w[Performance ElementState Visual ElementCache SmartWait Configuration]
  phase2_modules.each do |mod|
    Appom.const_get(mod)
    puts "✓ #{mod} module loads"
  rescue StandardError => e
    puts "✗ #{mod} module failed: #{e.message}"
  end

  puts 'Smoke test complete!'
end
