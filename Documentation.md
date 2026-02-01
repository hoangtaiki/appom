# Appom - Comprehensive User Documentation

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Core Features](#core-features)
5. [Page Object Model](#page-object-model)
6. [Element Management](#element-management)
7. [Waiting Strategies](#waiting-strategies)
8. [Performance Monitoring](#performance-monitoring)
9. [Visual Testing](#visual-testing)
10. [Element State Management](#element-state-management)
11. [Retry Mechanisms](#retry-mechanisms)
12. [Helper Methods](#helper-methods)
13. [Configuration](#configuration)
14. [Error Handling](#error-handling)
15. [Logging](#logging)
16. [Advanced Features](#advanced-features)
17. [Best Practices](#best-practices)
18. [Troubleshooting](#troubleshooting)

## Introduction

**Appom** is a comprehensive Page Object Model framework for mobile application testing using Appium. It provides a clean, semantic DSL for describing mobile applications with enhanced features including performance monitoring, visual testing, intelligent waiting, element state tracking, robust error handling, and advanced retry mechanisms.

### Key Benefits

- **Semantic DSL**: Write tests that read like natural language
- **Intelligent Waiting**: Smart wait strategies that adapt to your app's behavior
- **Performance Monitoring**: Track and optimize test execution performance
- **Visual Testing**: Automated visual regression testing capabilities
- **Element State Tracking**: Monitor element changes over time
- **Advanced Retry Logic**: Exponential backoff retry with configurable strategies
- **Helper Methods**: Rich set of utility methods for common operations
- **Robust Error Handling**: Comprehensive exception handling with detailed diagnostics
- **Flexible Configuration**: Environment-specific configuration management

## Installation

Add Appom to your Gemfile:

```ruby
gem 'appom'
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install appom
```

## Quick Start

### 1. Configure Appium Driver

```ruby
require 'appom'

# Register your Appium driver
Appom.register_driver do
  options = {
    caps: {
      platformName: 'iOS',
      deviceName: 'iPhone 14',
      app: '/path/to/your/app.ipa'
    },
    appium_lib: {
      server_url: 'http://localhost:4723/wd/hub'
    }
  }
  
  Appium::Driver.new(options, false)
end
```

### 2. Create Page Objects

```ruby
class LoginPage < Appom::Page
  element :email_field, :id, 'email'
  element :password_field, :id, 'password'
  element :login_button, :accessibility_id, 'login'
  element :error_message, :xpath, '//div[@class="error"]'

  def login(email, password)
    email_field.set email
    password_field.set password
    login_button.click
  end

  def error_displayed?
    error_message.present?
  end
end
```

### 3. Write Tests

```ruby
describe 'User Authentication' do
  let(:login_page) { LoginPage.new }

  it 'logs in successfully with valid credentials' do
    login_page.login('user@example.com', 'password123')
    expect(login_page).not_to have_error_message
  end
end
```

## Core Features

### Page Object Model

Appom implements the Page Object Model pattern with enhanced capabilities:

```ruby
class HomePage < Appom::Page
  # Define elements
  element :menu_button, :accessibility_id, 'menu'
  elements :menu_items, :xpath, '//div[@class="menu-item"]'
  
  # Define sections
  section :header, HeaderSection, :class, 'header'
  sections :product_cards, ProductCardSection, :class, 'product'
  
  # Custom methods
  def navigate_to_menu
    menu_button.click
    wait_for_menu_to_load
  end
  
  private
  
  def wait_for_menu_to_load
    wait_until { menu_items.count > 0 }
  end
end

# Section example
class HeaderSection < Appom::Section
  element :title, :xpath, './/h1'
  element :search_box, :xpath, './/input[@type="search"]'
end
```

## Element Management

### Element Definition

Appom provides several ways to define elements:

```ruby
class ProductPage < Appom::Page
  # Single element
  element :product_title, :id, 'title'
  element :price, :xpath, '//span[@class="price"]'
  element :add_to_cart, :accessibility_id, 'add_cart'
  
  # Multiple elements
  elements :product_images, :class, 'product-image'
  elements :review_stars, :xpath, '//div[@class="stars"]/span'
  
  # Element with text matching
  element :specific_button, :xpath, '//button', text: 'Submit'
  
  # Element with visibility check
  element :hidden_element, :id, 'secret', visible: false
end
```

### Automatic Element Helpers

For each element defined, Appom automatically creates helper methods:

```ruby
class ExamplePage < Appom::Page
  element :submit_button, :id, 'submit'
  elements :menu_items, :class, 'menu-item'
end

# Usage
page = ExamplePage.new

# Existence checkers (with explicit wait)
page.has_submit_button?     # true if element exists (waits up to max_wait_time)
page.has_no_submit_button?  # true if element doesn't exist (waits up to max_wait_time)

# State checkers (with explicit wait)
page.submit_button_enable   # waits for element to be enabled
page.submit_button_disable  # waits for element to be disabled

# Collection getters
page.get_all_menu_items     # returns all menu items with wait until not empty
```

### Sections and Section Collections

Sections allow you to group related elements:

```ruby
class CartSection < Appom::Section
  element :item_name, :xpath, './/span[@class="name"]'
  element :quantity, :xpath, './/input[@type="number"]'
  element :remove_button, :xpath, './/button[text()="Remove"]'
  
  def update_quantity(qty)
    quantity.clear
    quantity.set qty
  end
  
  def remove_item
    remove_button.click
  end
end

class CheckoutPage < Appom::Page
  # Single section
  section :payment_form, PaymentFormSection, :id, 'payment'
  
  # Multiple sections
  sections :cart_items, CartSection, :class, 'cart-item'
  
  def remove_all_items
    cart_items.each(&:remove_item)
  end
  
  def total_items
    get_all_cart_items.count
  end
end
```

For each element defined, Appom automatically creates helper methods:

```ruby
class ExamplePage < Appom::Page
  element :submit_button, :id, 'submit'
  elements :menu_items, :class, 'menu-item'
end

# Usage
## Waiting Strategies

### Basic Wait Methods

Appom provides sophisticated waiting strategies with explicit waits built into element checkers:

```ruby
class WaitingPage < Appom::Page
  element :loading_spinner, :class, 'spinner'
  element :result_content, :id, 'results'
end

page = WaitingPage.new

# Element existence with wait (using has_ methods)
page.has_loading_spinner?     # waits for element to appear
page.has_no_loading_spinner?  # waits for element to disappear

# State checking with wait
page.result_content_enable    # waits for element to be enabled
page.result_content_disable   # waits for element to be disabled
```

### Smart Wait Conditions

The SmartWait module provides advanced waiting capabilities:

```ruby
# Wait for element to be visible
Appom::SmartWait.wait_for_element_visible(element, timeout: 10)

# Wait for element to be clickable
Appom::SmartWait.wait_for_element_clickable(element, timeout: 15)

# Wait for specific text to appear
Appom::SmartWait.wait_for_text_present(element, 'Success', timeout: 5)

# Wait for text to change
initial_text = element.text
Appom::SmartWait.wait_for_text_to_change(element, initial_text, timeout: 10)

# Wait for element to be stable (no changes for duration)
Appom::SmartWait.wait_for_stable_element(element, timeout: 10, stable_duration: 2)
```

### Conditional Waiting

Create custom wait conditions:

```ruby
class SmartWaitPage < Appom::Page
  element :progress_bar, :class, 'progress'
  element :submit_button, :id, 'submit'

  def wait_for_processing_complete
    wait = Appom::SmartWait::ConditionalWait.new(
      timeout: 30,
      condition: ->(element) { element.attribute('aria-valuenow').to_i >= 100 }
    )
    
    wait.for_element(:class, 'progress')
  end
  
  def wait_for_any_result
    wait = Appom::SmartWait::ConditionalWait.new(timeout: 15)
    
    # Wait for any of these conditions
    wait.for_any_condition(
      [:id, 'success_message'],
      [:id, 'error_message'],
      [:class, 'timeout_notice']
    )
  end
end
```

### Advanced Wait Patterns

```ruby
# Wait with backoff strategy
wait = Appom::SmartWait::ConditionalWait.new(
  timeout: 20,
  interval: 0.5,
  backoff_factor: 1.5,
  max_interval: 3.0
)

result = wait.wait_until_with_backoff(
  condition: -> { complex_loading_complete? },
  description: 'complex loading process'
)

# Wait while condition is true
wait.wait_while(
  condition: -> { loading_indicator.displayed? },
  timeout: 30
)

# Wait for stable condition (must remain true for duration)
wait.wait_for_stable_condition(
  condition: -> { all_elements_loaded? },
  stable_duration: 2.0,
  timeout: 15
## Performance Monitoring

Appom includes comprehensive performance monitoring to help optimize your tests:

### Basic Performance Tracking

```ruby
class LoginPage < Appom::Page
  element :username, :id, 'username'
  element :password, :id, 'password'
  element :login_button, :id, 'login'

  def login_with_monitoring(username, password)
    # Time the entire login operation
    Appom::Performance.time_operation('complete_login') do
      self.username.set username
      self.password.set password
      self.login_button.click
    end
  end
  
  def detailed_login_monitoring(username, password)
    # Track individual operations
    monitor = Appom::Performance::Monitor.new
    
    username_id = monitor.start_timing('username_input')
    self.username.set username
    monitor.end_timing(username_id)
    
    password_id = monitor.start_timing('password_input')
    self.password.set password
    monitor.end_timing(password_id)
    
    login_id = monitor.start_timing('login_click')
    self.login_button.click
    monitor.end_timing(login_id)
    
    # Get performance statistics
    stats = monitor.stats
    puts "Performance Summary: #{stats}"
  end
end
```

### Performance Statistics

```ruby
# Get global performance monitor
monitor = Appom::Performance.monitor

# Time an operation
result = monitor.time_operation('page_load') do
  navigate_to_complex_page
end

# Manual timing
operation_id = monitor.start_timing('custom_operation', context: { page: 'checkout' })
perform_complex_operation
monitor.end_timing(operation_id, success: true)

# Get statistics for specific operation
login_stats = monitor.stats('login_process')
puts "Average login time: #{login_stats[:average_duration]}s"
puts "Success rate: #{login_stats[:success_rate]}%"
puts "Total attempts: #{login_stats[:total_calls]}"

# Get all performance metrics
all_stats = monitor.stats
puts "All operations: #{all_stats.keys}"
```

### Performance Analysis

```ruby
class PerformancePage < Appom::Page
  def analyze_page_performance
    monitor = Appom::Performance.monitor
    
    # Record baseline performance
    baseline_id = monitor.start_timing('page_baseline')
    load_page_elements
    monitor.end_timing(baseline_id)
    
    # Compare with previous runs
    stats = monitor.stats('page_baseline')
    
    if stats[:average_duration] > 5.0
      log_warn("Page loading slower than expected: #{stats[:average_duration]}s")
    end
    
    # Generate performance report
    report = monitor.generate_report
    save_performance_report(report)
  end
  
  private
  
  def save_performance_report(report)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filename = "appom_metrics_#{timestamp}.json"
    File.write(filename, report.to_json)
    log_info("Performance report saved to #{filename}")
  end
end
```

### Performance Configuration

```ruby
# Configure performance monitoring
Appom.configure do |config|
  config.performance_enabled = true
  config.performance_detailed_logging = true
  config.performance_report_threshold = 2.0  # seconds
  config.performance_auto_report = true
end

# Custom performance thresholds
monitor = Appom::Performance::Monitor.new
monitor.configure do |config|
  config.slow_operation_threshold = 3.0
  config.error_rate_threshold = 0.1
  config.report_interval = 100  # operations
end
## Visual Testing

Appom provides comprehensive visual regression testing capabilities:

### Basic Visual Testing

```ruby
class VisualTestPage < Appom::Page
  element :main_content, :id, 'main'
  element :sidebar, :class, 'sidebar'

  def verify_page_layout
    # Take full page visual regression test
    result = Appom::Visual.regression_test('homepage_layout')
    
    if result[:passed]
      log_info("Visual test passed: #{result[:comparison][:similarity]}% similarity")
    else
      log_error("Visual test failed: #{result[:comparison][:similarity]}% similarity")
      log_error("Diff image saved to: #{result[:diff_path]}")
    end
    
    result[:passed]
  end
  
  def verify_element_appearance
    # Test specific element
    result = Appom::Visual.regression_test(
      'sidebar_appearance',
      element: sidebar,
      threshold: 0.05  # 5% difference allowed
    )
    
    result[:passed]
  end
end
```

### Advanced Visual Testing

```ruby
class AdvancedVisualPage < Appom::Page
  element :header, :tag_name, 'header'
  element :product_grid, :class, 'products'

  def comprehensive_visual_test
    visual_helper = Appom::Visual::TestHelpers.new(
      baseline_dir: 'custom/baselines',
      results_dir: 'custom/results',
      threshold: 0.02
    )
    
    # Test with annotations
    result = visual_helper.take_visual_screenshot(
      'annotated_page',
      annotations: [
        { type: 'highlight', element: header, color: 'red' },
        { type: 'mask', element: product_grid, reason: 'dynamic_content' }
      ]
    )
    
    # Wait for visual stability before comparison
    visual_helper.wait_for_visual_stability(
      duration: 2.0,        # stable for 2 seconds
      check_interval: 0.5   # check every 500ms
    )
    
    # Compare with baseline
    comparison = visual_helper.visual_regression_test(
      'stable_page',
      full_page: true
    )
    
    comparison[:passed]
  end
  
  def element_visual_monitoring
    # Monitor element changes over time
    visual_helper = Appom::Visual::TestHelpers.new
    
    # Take initial screenshot
    visual_helper.take_visual_screenshot('button_initial', element: submit_button)
    
    # Perform interaction
    submit_button.click
    
    # Wait for changes to settle
    visual_helper.wait_for_visual_stability(element: submit_button)
    
    # Take final screenshot
    visual_helper.take_visual_screenshot('button_after_click', element: submit_button)
    
    # Compare states
    comparison = visual_helper.compare_images(
      'button_initial.png',
      'button_after_click.png',
      'button_diff.png'
    )
    
    log_info("Button changed by #{(1 - comparison[:similarity]) * 100}%")
  end
end
```

### Visual Testing Configuration

```ruby
# Configure visual testing
Appom.configure do |config|
  config.visual_testing_enabled = true
  config.visual_baseline_dir = 'test/visual_baselines'
  config.visual_results_dir = 'test/visual_results'
  config.visual_threshold = 0.01  # 1% difference threshold
  config.visual_auto_create_baselines = true
end

# Custom visual test setup
visual_config = {
  baseline_dir: 'custom/baselines',
  results_dir: 'custom/results', 
  threshold: 0.05,
  comparison_algorithm: 'structural_similarity'
}

visual_tester = Appom::Visual::TestHelpers.new(visual_config)
```

### Visual Test Reporting

```ruby
class VisualReportPage < Appom::Page
  def generate_visual_report
    visual_helper = Appom::Visual::TestHelpers.new
    
    # Run multiple visual tests
    tests = [
      'homepage_header',
      'navigation_menu', 
      'footer_section',
      'product_carousel'
    ]
    
    results = tests.map do |test_name|
      visual_helper.visual_regression_test(test_name)
    end
    
    # Generate comprehensive report
    summary = visual_helper.results_summary
    
    puts "Visual Test Summary:"
    puts "  Total tests: #{summary[:total]}"
    puts "  Passed: #{summary[:passed]}"
    puts "  Failed: #{summary[:failed]}"
    puts "  Pass rate: #{(summary[:passed].to_f / summary[:total] * 100).round(2)}%"
    
    # Save detailed report
    report_file = "visual_test_report_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    File.write(report_file, {
      summary: summary,
      detailed_results: results,
      timestamp: Time.now.iso8601
    }.to_json)
    
    summary[:passed] == summary[:total]
  end
end
```

## Element State Management

Appom provides advanced element state tracking to monitor changes over time:

### Basic State Tracking

```ruby
class StatePage < Appom::Page
  element :status_indicator, :id, 'status'
  element :progress_bar, :class, 'progress'
  element :submit_button, :id, 'submit'

  def monitor_form_submission
    tracker = Appom::ElementState.tracker
    
    # Start tracking elements
    button_id = tracker.track_element(submit_button, name: 'submit_button')
    progress_id = tracker.track_element(progress_bar, name: 'progress_bar')
    
    # Perform action
    submit_button.click
    
    # Monitor state changes
    10.times do
      sleep 1
      
      # Update and check for changes
      button_change = tracker.update_element_state(button_id)
      progress_change = tracker.update_element_state(progress_id)
      
      if button_change
        log_info("Button state changed: #{button_change[:changes]}")
      end
      
      if progress_change
        log_info("Progress changed: #{progress_change[:changes]}")
      end
    end
    
    # Get final states
    final_button_state = tracker.element_state(button_id)
    final_progress_state = tracker.element_state(progress_id)
    
    log_info("Final button state: #{final_button_state}")
    log_info("Final progress state: #{final_progress_state}")
  end
end
```

### Advanced State Monitoring

```ruby
class AdvancedStatePage < Appom::Page
  element :dynamic_content, :class, 'dynamic'
  
  def comprehensive_state_monitoring
    tracker = Appom::ElementState.tracker
    
    # Track with context
    element_id = tracker.track_element(
      dynamic_content,
      name: 'dynamic_content',
      context: { test_case: 'content_loading', page: 'dashboard' }
    )
    
    # Add observer for state changes
    tracker.add_observer do |event, element_id, data|
      case event
      when :element_tracked
        log_info("Started tracking: #{data[:name]}")
      when :state_changed
        log_info("Element #{data[:element_name]} changed: #{data[:changes]}")
      end
    end
    
    # Monitor for specific duration
    start_time = Time.now
    while Time.now - start_time < 30
      tracker.update_element_state(element_id)
      sleep 0.5
    end
    
    # Get state history
    history = tracker.state_history
    recent_changes = history.select { |h| h[:element_id] == element_id }
    
    log_info("Element had #{recent_changes.count} state changes")
    recent_changes.each do |change|
      log_info("  #{change[:timestamp]}: #{change[:changes]}")
    end
  end
  
  def state_based_assertions
    tracker = Appom::ElementState.tracker
    element_id = tracker.track_element(status_indicator, name: 'status')
    
    # Wait for specific state
    wait_until(timeout: 10) do
      current_state = tracker.element_state(element_id)
      current_state&.dig(:text) == 'Complete'
    end
    
    # Assert on state history
    history = tracker.state_history
    status_changes = history.select { |h| h[:element_name] == 'status' }
    
    expected_states = ['Pending', 'Processing', 'Complete']
    actual_states = status_changes.map { |c| c[:new_state][:text] }
    
    expect(actual_states).to eq(expected_states)
  end
end
```

### State Tracking Configuration

```ruby
# Configure state tracking
Appom.configure do |config|
  config.state_tracking_enabled = true
  config.state_tracking_interval = 1.0      # seconds
  config.state_history_limit = 1000         # events
  config.state_auto_update = true
  config.state_export_format = 'yaml'
end

# Custom state tracker
tracker = Appom::ElementState::Tracker.new
tracker.configure do |config|
  config.tracking_enabled = true
  config.max_tracked_elements = 50
  config.state_comparison_threshold = 0.1
end

# Export state data
timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
tracker.export_state_history("element_state_tracking_#{timestamp}.yaml")
```

### State Analysis

```ruby
class StateAnalysisPage < Appom::Page
  def analyze_element_behavior
    tracker = Appom::ElementState.tracker
    
    # Track multiple elements
    elements_to_track = {
      submit_button: submit_button,
      form_status: form_status,
      error_message: error_message
    }
    
    tracked_ids = elements_to_track.map do |name, element|
      [name, tracker.track_element(element, name: name.to_s)]
    end.to_h
    
    # Perform test scenario
    perform_form_interaction
    
    # Analyze patterns
    analysis = tracker.analyze_patterns(tracked_ids.values)
    
    puts "State Analysis Results:"
    puts "  Most active element: #{analysis[:most_active_element]}"
    puts "  Average changes per element: #{analysis[:avg_changes]}"
    puts "  Total monitoring duration: #{analysis[:duration]}s"
    
    # Generate state report
    report = {
      test_timestamp: Time.now.iso8601,
      elements_tracked: tracked_ids.keys,
      state_changes: tracker.state_history.count,
      analysis: analysis
    }
    
    File.write(
      "state_analysis_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json",
      JSON.pretty_generate(report)
    )
  end
end

## Retry Mechanisms

Appom provides sophisticated retry mechanisms with exponential backoff for handling flaky operations:

### Basic Retry Operations

```ruby
class RetryPage < Appom::Page
  include Appom::Retry::RetryMethods
  
  element :flaky_button, :id, 'flaky-button'
  element :unstable_text, :class, 'dynamic-text'
  element :loading_element, :class, 'loading'

  def robust_button_click
    # Retry element finding with default settings
    element = find_with_retry(:flaky_button)
    
    # Retry interaction with custom settings
    interact_with_retry(
      :flaky_button,
      :tap,
      max_attempts: 5,
      base_delay: 0.5,
      backoff_multiplier: 2.0
    )
  end
  
  def get_stable_text
    # Retry text retrieval with validation
    get_text_with_retry(
      :unstable_text,
      max_attempts: 4,
      validate_text: ->(text) { text.length > 0 && !text.include?('Loading') }
    )
  end
  
  def wait_for_element_state
    # Retry waiting for element state
    wait_for_state_with_retry(
      :loading_element,
      :displayed,
      max_attempts: 3,
      base_delay: 1.0
    )
  end
end
```

### Advanced Retry Configuration

```ruby
class AdvancedRetryPage < Appom::Page
  def custom_retry_behavior
    # Configure retry with custom settings
    config = Appom::Retry.configure_element_retry do |c|
      c.max_attempts = 5
      c.base_delay = 1.0
      c.backoff_multiplier = 1.5
      c.max_delay = 10.0
      c.retry_on_exceptions = [
        Appom::ElementNotFoundError,
        Appom::ElementStateError,
        StandardError
      ]
      
      # Custom retry condition
      c.retry_if = ->(exception, attempt) do
        # Don't retry on the 5th attempt or if it's a specific error
        attempt < 5 && !exception.message.include?('permanent_failure')
      end
      
      # Callback on each retry
      c.on_retry = ->(exception, attempt, delay) do
        log_warn("Retry attempt #{attempt} after #{delay}s: #{exception.message}")
      end
    end
    
    # Use custom configuration
    Appom::Retry.with_retry(config) do
      perform_flaky_operation
    end
  end
end
```

## Helper Methods

Appom provides a rich set of helper methods for common operations:

### Element Interaction Helpers

```ruby
class InteractiveHelperPage < Appom::Page
  include Appom::Helpers::ElementHelpers
  
  element :submit_button, :id, 'submit'
  element :text_field, :id, 'text_input'
  element :dynamic_content, :class, 'loading-content'
  element :hidden_button, :xpath, '//button[@style="display:none"]'
  
  def safe_submission(text)
    # Tap and wait for element to be enabled
    tap_and_wait(:submit_button, timeout: 10)
    
    # Get text with automatic retry
    current_text = get_text_with_retry(:text_field, retries: 3)
    
    # Wait for element to be visible then tap
    wait_and_tap(:submit_button)
    
    # Get attribute with fallback value
    status = get_attribute_with_fallback(:submit_button, 'aria-disabled', 'false')
    
    # Check if element contains specific text
    has_success = element_contains_text?(:status_message, 'Success')
    
    # Scroll to element and tap
    scroll_to_and_tap(:hidden_button, direction: :down)
  end
end
```

### Wait Helper Methods

```ruby
class WaitHelperPage < Appom::Page  
  include Appom::Helpers::WaitHelpers
  
  element :clickable_button, :id, 'button'
  element :text_element, :class, 'text'
  elements :list_items, :class, 'item'
  
  def advanced_waiting_examples
    # Wait for element to be clickable
    wait_for_clickable(:clickable_button, timeout: 15)
    
    # Wait for text to match pattern
    wait_for_text_match(:text_element, /success|complete/i, timeout: 10)
    
    # Wait for element to become invisible
    wait_for_invisible(:loading_spinner, timeout: 20)
    
    # Wait for specific count of elements
    wait_for_count(:list_items, 5, timeout: 12)
    
    # Wait with custom condition
    wait_for_condition(timeout: 10) do
      all_elements_loaded? && data_fetched?
    end
  end
end
```

### Debug Helper Methods

```ruby
class DebugHelperPage < Appom::Page
  include Appom::Helpers::DebugHelpers
  
  element :problem_element, :id, 'problem'
  
  def debug_test_failures
    # Take screenshot with automatic naming
    take_debug_screenshot('before_interaction')
    
    # Take screenshot of specific element
    take_element_screenshot(:problem_element, 'problem_state')
    
    # Take before/after screenshots around an action
    screenshot_action('button_click') do
      problem_element.click
    end
    
    # Take screenshot sequence during complex interaction
    screenshot_sequence('form_submission', interval: 2.0, max_duration: 10.0) do
      fill_out_form
      submit_form
    end
    
    # Take screenshot on failure with exception details
    begin
      risky_operation
    rescue => e
      screenshot_failure('risky_operation_failed', e)
      raise
    end
    
    # Dump page source for debugging
    dump_page_source('debug_page_source')
  end
end

## Configuration

Appom provides comprehensive configuration management with environment-specific settings:

### Basic Configuration

```ruby
# Global configuration
Appom.configure do |config|
  config.max_wait_time = 30
  config.implicit_wait = 5
  config.log_level = :info
  config.screenshot_on_failure = true
  config.performance_monitoring = true
  config.visual_testing_enabled = true
end
```

### Configuration File

Create an `appom.yml` file in your project root:

```yaml
# appom.yml
default: &default
  appom:
    max_wait_time: 30
    implicit_wait: 5
    log_level: info
    screenshot_dir: './screenshots'
    performance_monitoring: true
    visual_testing_enabled: true
  
  appium:
    server_url: 'http://localhost:4723/wd/hub'
    timeout: 60
    
development:
  <<: *default
  appom:
    log_level: debug
    
test:  
  <<: *default
  appium:
    server_url: 'http://ci-server:4723/wd/hub'
    
production:
  <<: *default
  appom:
    log_level: warn
    performance_monitoring: false
```

### Advanced Configuration

```ruby
class ConfiguredPage < Appom::Page
  def initialize
    super
    
    # Load configuration
    @config = Appom::Configuration::Config.new(
      config_file: 'config/appom.yml',
      environment: :test
    )
    
    # Apply configuration
    apply_page_config
  end
  
  private
  
  def apply_page_config
    # Get nested configuration values
    timeout = @config.get('appom.max_wait_time', 30)
    log_level = @config.get('appom.log_level', :info)
    
    # Set page-specific settings
    Appom.max_wait_time = timeout
    Appom.logger.level = log_level
    
    # Validate configuration
    @config.validate!
  end
end
```

### Environment-Specific Configuration

```ruby
# Detect and use environment-specific settings
config = Appom::Configuration::Config.new
current_env = config.environment

case current_env
when 'development'
  # Development-specific setup
  config.set('appom.screenshot_on_failure', true)
  config.set('appom.log_level', 'debug')
when 'ci'
  # CI-specific setup  
  config.set('appom.headless', true)
  config.set('appom.parallel_execution', true)
when 'production'
  # Production-specific setup
  config.set('appom.log_level', 'error')
  config.set('appom.performance_monitoring', false)
end

# Apply configuration
Appom.apply_config(config)
```

### Configuration Validation

```ruby
# Define custom configuration schema
config = Appom::Configuration::Config.new

# Validate against built-in schema
begin
  config.validate!
  puts "Configuration is valid"
rescue Appom::ConfigurationError => e
  puts "Configuration error: #{e.message}"
  puts "Details: #{e.validation_errors}"
end

# Check specific configuration keys
if config.key?('appom.max_wait_time')
  puts "Wait time configured: #{config.get('appom.max_wait_time')}s"
end

# Merge additional configuration
config.merge!({
  'custom' => {
    'feature_flags' => ['visual_testing', 'performance_monitoring'],
    'test_data_source' => 'fixtures/test_data.yml'
  }
})
```

## Error Handling

Appom provides comprehensive error handling with detailed exception information:

### Built-in Exception Types

```ruby
# Appom-specific exceptions
begin
  page.missing_element.click
rescue Appom::ElementNotFoundError => e
  puts "Element not found: #{e.element_selector}"
  puts "Timeout: #{e.timeout}s"
  puts "Last screenshot: #{e.screenshot_path}"
end

begin
  page.disabled_button.click
rescue Appom::ElementStateError => e
  puts "Element in wrong state: #{e.element_name}"
  puts "Expected: #{e.expected_state}, Actual: #{e.actual_state}"
end

begin
  wait_for_condition { false }
rescue Appom::WaitError => e
  puts "Wait timeout: #{e.message}"
  puts "Duration: #{e.timeout}s"
  puts "Condition: #{e.condition_description}"
end
```

### Error Recovery Patterns

```ruby
class ErrorHandlingPage < Appom::Page
  element :submit_button, :id, 'submit'
  element :error_message, :class, 'error'
  
  def robust_form_submission
    max_retries = 3
    attempt = 0
    
    begin
      attempt += 1
      submit_form
      
    rescue Appom::ElementNotFoundError => e
      if attempt < max_retries
        log_warn("Element not found, refreshing page (attempt #{attempt})")
        refresh_page
        retry
      else
        handle_permanent_failure(e)
        raise
      end
      
    rescue Appom::ElementStateError => e
      if attempt < max_retries
        log_warn("Element state error, waiting and retrying (attempt #{attempt})")
        wait_for_page_ready
        retry
      else
        take_error_screenshot(e)
        raise
      end
      
    rescue StandardError => e
      log_error("Unexpected error during form submission: #{e.message}")
      take_error_screenshot(e)
      dump_page_source_on_error
      raise
    end
  end
  
  private
  
  def handle_permanent_failure(error)
    log_error("Permanent failure after #{max_retries} attempts")
    take_error_screenshot(error)
    
    # Check if error message is displayed
    if has_error_message?
      error_text = error_message.text
      log_error("Application error message: #{error_text}")
    end
  end
  
  def take_error_screenshot(error)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filename = "error_#{error.class.name.split('::').last}_#{timestamp}.png"
    Appom::Screenshot.take_screenshot(filename)
    log_info("Error screenshot saved: #{filename}")
  end
  
  def dump_page_source_on_error
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S') 
    filename = "page_source_error_#{timestamp}.xml"
    File.write(filename, page.page_source)
    log_info("Page source dumped: #{filename}")
  end
end
```

### Global Error Handling

```ruby
# Configure global error handling
Appom.configure do |config|
  config.screenshot_on_error = true
  config.page_source_on_error = true
  config.error_retry_attempts = 2
  config.error_recovery_delay = 1.0
  
  # Custom error handler
  config.error_handler = ->(error, context) do
    case error
    when Appom::ElementNotFoundError
      # Handle missing elements
      handle_missing_element_error(error, context)
    when Appom::ElementStateError  
      # Handle state issues
      handle_state_error(error, context)
    else
      # Handle other errors
      handle_generic_error(error, context)
    end
  end
end

def handle_missing_element_error(error, context)
  log_warn("Element not found: #{error.element_selector}")
  
  # Try alternative selectors
  alternative_selectors = context[:alternative_selectors]
  if alternative_selectors
    alternative_selectors.each do |selector|
      begin
        element = page.find_element(selector)
        log_info("Found element using alternative selector: #{selector}")
        return element
      rescue Appom::ElementNotFoundError
        next
      end
    end
  end
  
  # Take diagnostic screenshot
  Appom::Screenshot.take_screenshot("missing_element_#{Time.now.to_i}.png")
  raise error
end
```

### Custom Exception Classes

```ruby
module CustomErrors
  class BusinessLogicError < Appom::AppomError
    attr_reader :business_rule, :violated_condition
    
    def initialize(business_rule, violated_condition, message = nil)
      @business_rule = business_rule
      @violated_condition = violated_condition
      super(message || "Business rule '#{business_rule}' violated: #{violated_condition}")
    end
  end
  
  class DataValidationError < Appom::AppomError
    attr_reader :field_name, :expected_format, :actual_value
    
    def initialize(field_name, expected_format, actual_value)
      @field_name = field_name
      @expected_format = expected_format  
      @actual_value = actual_value
      super("Data validation failed for '#{field_name}': expected #{expected_format}, got #{actual_value}")
    end
  end
end

class ValidatingPage < Appom::Page
  include CustomErrors
  
  element :email_field, :id, 'email'
  
  def validate_email_format
    email_value = email_field.text
    
    unless email_value.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\z/i)
      raise DataValidationError.new('email', 'valid email format', email_value)
    end
    
    email_value
  end
end

## Logging

Appom provides comprehensive logging capabilities for debugging and monitoring:

### Basic Logging

```ruby
class LoggingPage < Appom::Page
  include Appom::Logging
  
  element :search_box, :id, 'search'
  
  def search_with_logging(term)
    log_info("Starting search for term: #{term}")
    
    begin
      log_debug("Clearing search box")
      search_box.clear
      
      log_debug("Entering search term")
      search_box.set term
      
      log_debug("Submitting search")
      search_box.send_keys(:return)
      
      log_info("Search completed successfully")
      
    rescue => e
      log_error("Search failed: #{e.message}")
      log_debug("Search error details", {
        term: term,
        error_class: e.class.name,
        backtrace: e.backtrace.first(5)
      })
      raise
    end
  end
end
```

### Advanced Logging Configuration

```ruby
# Configure logging globally
Appom.configure do |config|
  config.log_level = :debug
  config.log_file = 'logs/appom.log'
  config.log_format = :json
  config.log_rotation = :daily
  config.log_max_size = 10 # MB
end

# Custom logger setup
logger = Logger.new('custom_appom.log')
logger.level = Logger::DEBUG
logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime}] #{severity}: #{progname} - #{msg}\n"
end

Appom.logger = logger
```

### Contextual Logging

```ruby
class ContextualLoggingPage < Appom::Page
  include Appom::Logging
  
  def complex_operation_with_context
    # Set logging context
    with_logging_context(
      operation: 'complex_operation',
      user_id: current_user_id,
      test_case: 'user_workflow'
    ) do
      
      log_info("Starting complex operation")
      
      step_1_result = perform_step_1
      log_debug("Step 1 completed", { result: step_1_result })
      
      step_2_result = perform_step_2(step_1_result)
      log_debug("Step 2 completed", { result: step_2_result })
      
      final_result = finalize_operation(step_2_result)
      log_info("Complex operation completed", { final_result: final_result })
      
      final_result
    end
  end
  
  private
  
  def with_logging_context(context, &block)
    old_context = Thread.current[:logging_context]
    Thread.current[:logging_context] = context
    
    begin
      yield
    ensure
      Thread.current[:logging_context] = old_context  
    end
  end
end
```

### Performance and Error Logging

```ruby
class DiagnosticLoggingPage < Appom::Page
  include Appom::Logging
  
  def operation_with_performance_logging
    start_time = Time.now
    log_info("Starting timed operation")
    
    begin
      # Time critical sections
      log_timing("element_lookup") do
        element = find_critical_element
        log_debug("Element found", {
          locator: element.tag_name,
          location: element.location,
          size: element.size
        })
        element
      end
      
      log_timing("interaction") do
        element.click
      end
      
    rescue => e
      duration = Time.now - start_time
      log_error("Operation failed after #{duration}s", {
        error: e.message,
        error_class: e.class.name,
        duration: duration
      })
      
      # Take diagnostic screenshot on error
      screenshot_path = take_diagnostic_screenshot
      log_info("Diagnostic screenshot saved", { path: screenshot_path })
      
      raise
    ensure
      total_duration = Time.now - start_time
      log_info("Operation completed", { total_duration: total_duration })
    end
  end
  
  private
  
  def log_timing(operation_name, &block)
    start_time = Time.now
    log_debug("Starting #{operation_name}")
    
    result = yield
    
    duration = Time.now - start_time
    log_debug("#{operation_name} completed in #{(duration * 1000).round(2)}ms")
    
    result
  end
end
```

## Best Practices

Here are recommended practices for using Appom effectively:

### Page Object Design

```ruby
# Good: Clear, focused page objects
class LoginPage < Appom::Page
  # Use semantic element names
  element :username_field, :id, 'username'
  element :password_field, :id, 'password'  
  element :login_button, :xpath, '//button[@type="submit"]'
  element :error_message, :class, 'error-message'
  
  # Provide high-level methods
  def login(username, password)
    username_field.set username
    password_field.set password
    login_button.click
    HomePage.new # Return next page object
  end
  
  def has_login_error?
    has_error_message?
  end
  
  def login_error_text
    error_message.text
  end
end

# Good: Use sections for repeated components
class NavigationSection < Appom::Section
  element :home_link, :link_text, 'Home'
  element :profile_link, :link_text, 'Profile'
  element :logout_link, :link_text, 'Logout'
  
  def navigate_to_home
    home_link.click
    HomePage.new
  end
end

class BasePage < Appom::Page  
  section :navigation, NavigationSection, :nav, 'main-nav'
end
```

### Robust Element Strategies  

```ruby
class RobustElementsPage < Appom::Page
  # Prefer ID and accessibility selectors
  element :submit_button, :accessibility_id, 'submit_button'
  
  # Use data attributes for test-specific selectors
  element :dynamic_content, :xpath, '//*[@data-testid="content"]'
  
  # Avoid brittle selectors
  # Bad: element :button, :xpath, '//div[3]/span[2]/button[1]'  
  # Good: element :button, :xpath, '//button[@aria-label="Submit Form"]'
  
  # Use text matching carefully
  element :save_button, :xpath, '//button[contains(text(), "Save")]'
  
  # Handle dynamic elements with smart waiting
  def wait_for_dynamic_content
    # Use built-in waits
    has_dynamic_content?
    
    # Or custom conditions
    wait_until(timeout: 15) do
      dynamic_content.displayed? && 
      !dynamic_content.text.empty?
    end
  end
end
```

### Test Organization

```ruby
# Organize tests by user journeys
describe 'User Authentication Journey' do
  let(:login_page) { LoginPage.new }
  let(:home_page) { HomePage.new }
  
  context 'with valid credentials' do
    it 'logs in successfully' do
      home_page = login_page.login('valid@email.com', 'password123')
      expect(home_page).to be_logged_in
    end
  end
  
  context 'with invalid credentials' do
    it 'shows error message' do
      login_page.login('invalid@email.com', 'wrong_password')
      expect(login_page).to have_login_error
      expect(login_page.login_error_text).to include('Invalid credentials')
    end
  end
end

# Use data-driven testing for variations
describe 'Form Validation' do
  let(:signup_page) { SignupPage.new }
  
  invalid_emails = [
    'notanemail',
    '@invalid.com', 
    'user@',
    'user@.com'
  ]
  
  invalid_emails.each do |invalid_email|
    it "rejects invalid email: #{invalid_email}" do
      signup_page.fill_email(invalid_email)
      signup_page.submit_form
      
      expect(signup_page).to have_email_validation_error
    end
  end
end
```

### Performance Optimization

```ruby
class OptimizedPage < Appom::Page
  # Cache stable elements
  element :header, :tag_name, 'header', cache: true
  
  # Don't cache dynamic elements  
  element :status_message, :class, 'status', cache: false
  
  def efficient_batch_operations
    # Batch similar operations
    form_data = {
      first_name: 'John',
      last_name: 'Doe', 
      email: 'john@example.com'
    }
    
    # Fill all fields without individual waits
    form_data.each do |field, value|
      send("#{field}_field").set(value)
    end
    
    # Single wait after all operations
    submit_button.click
    wait_for_success_message
  end
  
  def smart_element_reuse
    # Reuse found elements
    @form_element ||= find_element(:id, 'contact-form')
    
    # Use scoped finding within parent element
    first_name_field = @form_element.find_element(:name, 'firstName')
    last_name_field = @form_element.find_element(:name, 'lastName')
  end
end
```

### Error Handling Best Practices

```ruby
class ReliableTestPage < Appom::Page
  def robust_interaction_pattern
    max_retries = 3
    attempt = 0
    
    begin
      attempt += 1
      perform_critical_action
      
    rescue Appom::ElementNotFoundError => e
      if attempt < max_retries
        log_warn("Element not found on attempt #{attempt}, retrying...")
        wait_for_page_stability
        retry
      else
        capture_failure_context(e)
        raise
      end
      
    rescue Appom::ElementStateError => e
      if attempt < max_retries
        log_warn("Element state issue on attempt #{attempt}, retrying...")
        refresh_element_state
        retry  
      else
        capture_failure_context(e)
        raise
      end
    end
  end
  
  private
  
  def capture_failure_context(error)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    
    # Take screenshot
    screenshot_path = "failure_#{timestamp}.png"
    take_screenshot(screenshot_path)
    
    # Capture page source
    source_path = "page_source_#{timestamp}.html"
    File.write(source_path, page.page_source)
    
    # Log comprehensive context
    log_error("Test failure context", {
      error: error.message,
      screenshot: screenshot_path,
      page_source: source_path,
      current_url: current_url,
      timestamp: timestamp
    })
  end
end

## Troubleshooting

Common issues and solutions when using Appom:

### Element Not Found Issues

```ruby
# Problem: Elements not found intermittently
# Solution: Use proper waiting strategies

class TroubleshootingPage < Appom::Page
  element :dynamic_button, :id, 'dynamic-btn'
  
  def find_dynamic_element
    # Instead of immediate access
    # dynamic_button.click  # May fail
    
    # Use has_ methods with built-in wait
    if has_dynamic_button?
      dynamic_button.click
    else
      log_warn("Dynamic button not found after waiting")
      take_debug_screenshot('dynamic_button_missing')
    end
  end
  
  # Alternative: Use explicit waits
  def find_with_explicit_wait
    wait = Appom::SmartWait::ConditionalWait.new(timeout: 15)
    element = wait.for_element(:id, 'dynamic-btn') do |el|
      el.displayed? && el.enabled?
    end
    element.click
  end
end
```

### Performance Issues

```ruby
# Problem: Slow test execution
# Solution: Optimize waits and caching

class OptimizedPage < Appom::Page
  # Cache stable elements
  element :header, :tag_name, 'header', cache: true
  
  # Reduce unnecessary waits
  def optimized_interaction
    # Batch operations
    elements_data = [
      [:first_name, 'John'],
      [:last_name, 'Doe'],
      [:email, 'john@example.com']
    ]
    
    # Fill all fields without individual waits
    elements_data.each do |field, value|
      send("#{field}_field").set(value, wait: false)
    end
    
    # Single verification at the end
    submit_button.click
    wait_for_form_submission
  end
  
  # Use performance monitoring to identify bottlenecks
  def profile_slow_operation
    monitor = Appom::Performance::Monitor.new
    
    operation_id = monitor.start_timing('slow_operation')
    perform_slow_operation
    monitor.end_timing(operation_id)
    
    stats = monitor.stats('slow_operation')
    if stats[:average_duration] > 5.0
      log_warn("Operation slower than expected: #{stats[:average_duration]}s")
    end
  end
end
```

### Flaky Tests

```ruby
# Problem: Tests fail inconsistently
# Solution: Implement robust retry patterns

class FlakeFreeTestPage < Appom::Page
  include Appom::Retry::RetryMethods
  
  def stable_test_pattern
    # Use retry for flaky elements
    element = find_with_retry(:flaky_element, max_attempts: 3)
    
    # Retry interactions with validation
    interact_with_retry(
      :submit_button,
      :click,
      max_attempts: 2,
      validate_after: ->(el) { el.attribute('disabled') != 'true' }
    )
    
    # Wait for stable state before assertions
    wait_until(timeout: 10) do
      has_success_message? && !has_loading_indicator?
    end
  end
  
  def debug_flaky_behavior
    # Add extensive logging for flaky tests
    log_info("Starting flaky operation debug")
    
    # Capture state before operation
    before_state = capture_page_state
    log_debug("State before operation", before_state)
    
    begin
      perform_flaky_operation
    rescue => e
      # Capture state on failure
      after_state = capture_page_state
      log_error("Operation failed", {
        error: e.message,
        before_state: before_state,
        after_state: after_state
      })
      
      take_debug_screenshot('flaky_operation_failed')
      raise
    end
  end
  
  private
  
  def capture_page_state
    {
      url: current_url,
      title: page.title,
      visible_elements: count_visible_elements,
      timestamp: Time.now.iso8601
    }
  end
end
```

### Configuration Issues

```ruby
# Problem: Environment-specific failures
# Solution: Proper configuration management

# Check current configuration
def debug_configuration
  config = Appom::Configuration::Config.new
  
  puts "Current environment: #{config.environment}"
  puts "Config file: #{config.config_file}"
  puts "Max wait time: #{config.get('appom.max_wait_time')}s"
  puts "Log level: #{config.get('appom.log_level')}"
  
  # Validate configuration
  begin
    config.validate!
    puts "Configuration is valid"
  rescue Appom::ConfigurationError => e
    puts "Configuration issues found:"
    e.validation_errors.each do |error|
      puts "  - #{error}"
    end
  end
end

# Environment-specific debugging
def setup_debug_environment
  case ENV['TEST_ENV']
  when 'ci'
    Appom.configure do |config|
      config.max_wait_time = 60      # Longer waits for CI
      config.screenshot_on_failure = true
      config.log_level = :info       # Reduce log verbosity
    end
  when 'local'
    Appom.configure do |config|
      config.max_wait_time = 10      # Shorter waits locally  
      config.log_level = :debug      # Verbose logging
      config.visual_testing_enabled = false  # Skip visual tests
    end
  end
end
```

### Memory and Resource Management

```ruby
# Problem: Memory leaks in long test runs
# Solution: Proper cleanup and resource management

class ResourceManagedPage < Appom::Page
  def initialize
    super
    @cleanup_tasks = []
  end
  
  def operation_with_cleanup
    # Register cleanup tasks
    register_cleanup { clear_temporary_files }
    register_cleanup { reset_application_state }
    
    begin
      perform_operation
    ensure
      # Always perform cleanup
      perform_cleanup
    end
  end
  
  def large_dataset_operation
    # Process in batches to manage memory
    large_dataset.each_slice(100) do |batch|
      process_batch(batch)
      
      # Clear caches periodically
      Appom::ElementCache.clear_stale_entries
      
      # Force garbage collection for long operations
      GC.start if batch.size % 500 == 0
    end
  end
  
  private
  
  def register_cleanup(&block)
    @cleanup_tasks << block
  end
  
  def perform_cleanup
    @cleanup_tasks.each do |task|
      begin
        task.call
      rescue => e
        log_warn("Cleanup task failed: #{e.message}")
      end
    end
    @cleanup_tasks.clear
  end
end
```

### Debugging Tools

```ruby
# Comprehensive debugging utilities
class DebuggingPage < Appom::Page
  def comprehensive_debug_info
    debug_info = {
      timestamp: Time.now.iso8601,
      driver_info: get_driver_info,
      page_state: get_page_state,
      element_states: get_element_states,
      performance_metrics: get_performance_info,
      recent_errors: get_recent_errors
    }
    
    # Save debug info to file
    debug_file = "debug_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    File.write(debug_file, JSON.pretty_generate(debug_info))
    
    log_info("Debug information saved to #{debug_file}")
    debug_info
  end
  
  private
  
  def get_driver_info
    {
      session_id: Appom.driver.session_id,
      capabilities: Appom.driver.capabilities.as_json,
      current_context: Appom.driver.current_context
    }
  rescue => e
    { error: e.message }
  end
  
  def get_page_state
    {
      url: current_url,
      title: page.title,
      source_length: page.page_source.length,
      window_size: Appom.driver.window_size
    }
  rescue => e
    { error: e.message }  
  end
  
  def get_element_states
    # Check states of key elements
    key_elements = [:submit_button, :error_message, :loading_spinner]
    
    key_elements.map do |element_name|
      next unless respond_to?(element_name)
      
      begin
        element = send(element_name)
        {
          name: element_name,
          displayed: element.displayed?,
          enabled: element.enabled?,
          text: element.text.truncate(100),
          location: element.location,
          size: element.size
        }
      rescue => e
        {
          name: element_name,
          error: e.message
        }
      end
    end.compact
  end
  
  def get_performance_info
    if defined?(Appom::Performance)
      monitor = Appom::Performance.monitor
      {
        total_operations: monitor.stats.dig(:summary, :total_operations),
        average_duration: monitor.stats.dig(:summary, :average_duration),
        slowest_operation: monitor.stats.dig(:summary, :slowest_operation)
      }
    else
      { status: 'Performance monitoring not enabled' }
    end
  end
  
  def get_recent_errors
    # Get recent errors from logs if available
    log_file = Appom.configuration&.log_file
    return { status: 'Log file not configured' } unless log_file && File.exist?(log_file)
    
    recent_lines = File.readlines(log_file).last(50)
    error_lines = recent_lines.select { |line| line.include?('ERROR') }
    
    {
      total_recent_errors: error_lines.count,
      recent_errors: error_lines.last(5)
    }
  rescue => e
    { error: e.message }
  end
end
```

This comprehensive documentation covers all major features of Appom including:
- Page Object Model with elements, sections, and collections
- Waiting strategies with explicit waits built into has_/has_no_ methods
- Performance monitoring with detailed metrics
- Visual testing with regression capabilities  
- Element state tracking for monitoring changes
- Advanced retry mechanisms with exponential backoff
- Rich helper methods for common operations
- Comprehensive configuration management
- Robust error handling with recovery patterns
- Detailed logging with contextual information
- Best practices for reliable test automation
- Troubleshooting guide for common issues

Each feature is documented with practical examples that developers can use as reference implementations in their own test automation projects.

### Visual Test Reporting

```ruby
# Generate comprehensive visual test report
report_path = visual.generate_report
puts "Visual test report: #{report_path}"

# Get results summary
summary = visual.results_summary
puts "Visual tests run: #{summary[:tests_run]}"
puts "Pass rate: #{summary[:pass_rate]}%"
```

## Element State Management

Track element changes over time:

### Basic State Tracking

```ruby
# Track element state changes
state_tracker = Appom::ElementState::StateTracker.new

# Start tracking an element
state_tracker.track_element(login_button, 'login_button')

# Simulate user interactions
login_button.click
sleep 2

# Get state history
history = state_tracker.get_element_history('login_button')
history.each do |state|
  puts "#{state[:timestamp]}: #{state[:state]}"
end
```

### Advanced State Management

```ruby
class FormPage < Appom::Page
  element :form_field, :id, 'field'
  
  def monitor_form_changes
    # Track specific state changes
    Appom::ElementState.monitor_element(form_field) do |changes|
      changes.each do |change|
        puts "Field changed: #{change[:property]} from #{change[:old_value]} to #{change[:new_value]}"
      end
    end
  end
  
  def wait_for_state_change
    # Wait for element to change state
    Appom::ElementState.wait_for_state_change(
      form_field,
      property: 'value',
      timeout: 10
    )
  end
end
```

### State Persistence

```ruby
# Export state history to YAML
state_tracker.export_to_yaml('element_states.yml')

# Load state history from YAML
state_tracker.load_from_yaml('element_states.yml')

# Get state analysis
analysis = state_tracker.analyze_states
puts "Most changed element: #{analysis[:most_active_element]}"
puts "State change frequency: #{analysis[:change_frequency]}"
```

## Configuration

### Basic Configuration

```ruby
Appom.configure do |config|
  config.max_wait_time = 30
  config.retry_attempts = 3
  config.retry_delay = 1
  config.smart_wait_enabled = true
  config.element_cache_enabled = true
  config.performance_monitoring = true
  config.visual_testing = true
  config.log_level = :info
end
```

### Environment-Specific Configuration

Create `appom.yml` in your project root:

```yaml
default: &default
  max_wait_time: 30
  retry_attempts: 3
  element_cache_enabled: true
  
test:
  <<: *default
  log_level: debug
  performance_monitoring: true
  
production:
  <<: *default
  log_level: warn
  performance_monitoring: false
  
ios:
  <<: *default
  platform_specific:
    swipe_duration: 1000
    tap_duration: 250
    
android:
  <<: *default
  platform_specific:
    swipe_duration: 800
    tap_duration: 100
```

Load configuration:

```ruby
# Load with environment detection
config = Appom::Configuration::Config.new

# Load specific environment
config = Appom::Configuration::Config.new(environment: 'test')

# Access configuration values
wait_time = config.get('max_wait_time', 10)
cache_enabled = config.get('element_cache_enabled', true)
```

### Dynamic Configuration

```ruby
# Update configuration at runtime
Appom.configuration.set('max_wait_time', 45)

# Environment-specific overrides
if Appom.ios?
  Appom.configuration.merge!({
    'swipe_duration' => 1000,
    'platform_name' => 'iOS'
  })
end
```

## Error Handling

Appom provides comprehensive error handling:

### Exception Types

```ruby
begin
  element.click
rescue Appom::ElementNotFoundError => e
  puts "Element not found: #{e.element_info}"
  puts "Suggestions: #{e.suggestions}"
rescue Appom::ElementNotInteractableError => e
  puts "Element not interactable: #{e.message}"
  puts "Element state: #{e.element_state}"
rescue Appom::TimeoutError => e
  puts "Timeout waiting for: #{e.operation}"
  puts "Duration: #{e.duration}s"
end
```

### Error Recovery

```ruby
class RobustPage < Appom::Page
  element :submit_button, :id, 'submit'
  
  def click_submit_with_retry
    retry_on_error(
      max_attempts: 3,
      delay: 1,
      exceptions: [Appom::ElementNotInteractableError]
    ) do
      submit_button.click
    end
  end
  
  def safe_element_interaction
    with_error_handling do
      submit_button.click
    end
  rescue Appom::AppomError => e
    log_error("Failed to interact with element: #{e.message}")
    take_screenshot_on_error
    false
  end
end
```

## Logging

Comprehensive logging system:

### Basic Logging

```ruby
class TestPage < Appom::Page
  include Appom::Logging
  
  def perform_action
    log_info "Starting action"
    
    begin
      element.click
      log_info "Action completed successfully"
    rescue => e
      log_error "Action failed: #{e.message}"
      log_debug "Stack trace: #{e.backtrace.join("\n")}"
    end
  end
end
```

### Log Configuration

```ruby
Appom.configure do |config|
  config.log_level = :debug
  config.log_file = 'logs/appom.log'
  config.log_format = :json
  config.log_screenshots = true
  config.log_performance = true
end
```

### Custom Loggers

```ruby
# Use custom logger
require 'logger'
custom_logger = Logger.new('custom.log')
Appom.logger = custom_logger

# Log to multiple destinations
Appom.configure do |config|
  config.loggers = [
    { type: :file, path: 'test.log' },
    { type: :stdout, level: :info },
    { type: :syslog, facility: 'user' }
  ]
end
```

## Advanced Features

### Custom Element Types

```ruby
class CustomElement < Appom::Element
  def toggle
    click
    wait_for_state_change
  end
  
  def wait_for_state_change
    wait_until(timeout: 5) do
      attribute('aria-checked') != @previous_state
    end
  end
end

class PageWithCustomElements < Appom::Page
  element :switch, CustomElement, :id, 'toggle_switch'
  
  def toggle_setting
    switch.toggle
  end
end
```

### Cucumber Integration

```ruby
# features/support/appom.rb
require 'appom/cucumber'

Before do
  @login_page = LoginPage.new
  @home_page = HomePage.new
end

After do |scenario|
  if scenario.failed?
    screenshot_path = Appom::Screenshot.capture(
      file_path: "screenshots/#{scenario.name}_failed.png"
    )
    embed screenshot_path, 'image/png'
  end
end
```

### Parallel Testing Support

```ruby
# Configure for parallel execution
Appom.configure do |config|
  config.parallel_enabled = true
  config.driver_pool_size = 4
  config.thread_safe_logging = true
end

# Thread-safe page objects
class ThreadSafePage < Appom::Page
  def initialize
    super
    @mutex = Mutex.new
  end
  
  def thread_safe_operation
    @mutex.synchronize do
      # Thread-safe operations
      element.click
    end
  end
end
```

## Advanced Page Object Model Features

### Advanced Element Definition

Appom provides many advanced features for element definition that go beyond basic locators:

#### Element Options

Elements support various options to customize their behavior:

```ruby
class AdvancedPage < Appom::Page
  # Element with text matching
  element :welcome_msg, :id, 'message', text: 'Welcome back!'
  
  # Element with visibility requirement
  element :visible_button, :class, 'btn', visible: true
  
  # Element that must be enabled
  element :submit_btn, :id, 'submit', enabled: true
  
  # Element with custom timeout
  element :slow_element, :xpath, '//div[@loading]', timeout: 30
  
  # Multiple options combined
  element :specific_item, :class, 'item', text: 'Target Item', visible: true, timeout: 15
end
```

#### Supported Element Options

- **`:text`** - Element must contain specific text
- **`:visible`** - Element must be visible/displayed (true/false)
- **`:enabled`** - Element must be enabled/disabled (true/false)  
- **`:timeout`** - Custom timeout for finding this element

#### Comprehensive Helper Methods

Every element definition automatically generates helper methods:

```ruby
class PageWithHelpers < Appom::Page
  element :login_button, :id, 'login_btn'
  elements :menu_items, :class, 'menu-item'
  
  # Automatically generated methods for single elements:
  # - login_button              # Find the element
  # - has_login_button          # Check if element exists  
  # - has_no_login_button       # Check if element doesn't exist
  # - login_button_enable       # Wait for element to be enabled
  # - login_button_disable      # Wait for element to be disabled
  # - login_button_params       # Get element find parameters
  
  # Automatically generated methods for multiple elements:
  # - menu_items                # Find all matching elements
  # - has_menu_items           # Check if at least one exists
  # - has_no_menu_items        # Check if none exist  
  # - get_all_menu_items       # Wait until not empty, then return all
  # - menu_items_params        # Get element find parameters
end

# Using the generated helper methods
page = PageWithHelpers.new

# Check existence
if page.has_login_button
  page.login_button.click
end

# Wait for element states
page.login_button_enable  # Wait until enabled
page.login_button_disable # Wait until disabled

# Get find parameters
params = page.login_button_params  # [:id, 'login_btn']
```

#### Runtime Arguments

Elements support runtime arguments for dynamic locators:

```ruby
class DynamicPage < Appom::Page
  # Use %s placeholders in locators
  element :dynamic_item, :xpath, '//div[@data-id="%s"]'
  element :user_profile, :id, '%s_profile'
  
  # Multiple placeholders
  element :grid_cell, :xpath, '//tr[%s]/td[%s]'
  
  def select_item(item_id)
    # Pass runtime arguments to customize locator
    dynamic_item(item_id).click
  end
  
  def check_item_exists(item_id)
    has_dynamic_item(item_id)
  end
  
  def select_cell(row, col)
    grid_cell(row, col).click
  end
  
  def view_user_profile(username)
    user_profile(username).click
  end
end
```

### Advanced Section Features

Sections provide powerful ways to organize complex page structures:

#### Basic Section Usage

```ruby
class HeaderSection < Appom::Section
  element :logo, :id, 'logo'
  element :search_box, :id, 'search'
  element :menu_button, :id, 'menu'
  
  def search_for(query)
    search_box.send_keys(query)
    search_box.send_keys(:return)
  end
  
  def navigate_to_menu
    menu_button.click
  end
end

class HomePage < Appom::Page
  section :header, HeaderSection, :class, 'header'
  sections :product_cards, ProductCardSection, :class, 'product-card'
  
  def search_for_product(query)
    header.search_for(query)
  end
  
  def select_first_product
    product_cards.first.select
  end
end
```

#### Section with Default Search Arguments

```ruby
class NavigationSection < Appom::Section
  # Set default search arguments for the section
  def self.default_search_arguments
    [:class, 'navigation-bar']
  end
  
  element :home_link, :link_text, 'Home'
  element :about_link, :link_text, 'About'
  element :contact_link, :link_text, 'Contact'
  
  def navigate_to(page_name)
    case page_name.downcase
    when 'home' then home_link.click
    when 'about' then about_link.click
    when 'contact' then contact_link.click
    end
  end
end

# Using default search arguments - no need to specify locator
class HomePage < Appom::Page
  section :navigation, NavigationSection  # Uses default_search_arguments
end
```

#### Anonymous Sections with Blocks

```ruby
class HomePage < Appom::Page
  # Define section inline with a block
  section :footer, :id, 'footer' do
    element :copyright, :class, 'copyright'
    element :contact_link, :link_text, 'Contact'
    element :privacy_link, :link_text, 'Privacy'
    
    def get_copyright_year
      copyright.text.match(/\d{4}/)&.to_s
    end
  end
  
  # Multiple anonymous sections
  section :sidebar, :class, 'sidebar' do
    elements :widget_titles, :class, 'widget-title'
    element :search_widget, :id, 'search-widget'
    
    def widget_count
      widget_titles.size
    end
  end
end
```

#### Section Inheritance and Hierarchy

```ruby
# Base section class with common functionality
class BaseSection < Appom::Section
  def scroll_into_view
    root_element.location_once_scrolled_into_view
  end
  
  def highlight
    # Use visual testing to highlight this section
    parent_page.screenshot_with_highlight(self)
  end
end

# Specialized section inheriting from base
class ArticleSection < BaseSection
  element :title, :tag, 'h2'
  element :content, :class, 'content'
  element :author, :class, 'author'
  section :comments, CommentsSection, :class, 'comments'
  
  def article_info
    {
      title: title.text,
      content: content.text.truncate(100),
      author: author.text,
      comment_count: comments.comment_count,
      page_title: parent_page.title  # Access parent page
    }
  end
  
  def share_article
    # Access parent page methods
    parent_page.login_if_needed
    share_button.click
  end
end

class CommentsSection < BaseSection
  elements :comment_items, :class, 'comment'
  element :comment_box, :id, 'new-comment'
  element :submit_button, :class, 'submit-comment'
  
  def comment_count
    comment_items.size
  end
  
  def post_comment(text)
    scroll_into_view
    comment_box.send_keys(text)
    submit_button.click
    
    # Wait for new comment to appear
    parent_page.wait_for_element_count_change(:comment_items)
  end
  
  def latest_comment
    comment_items.first.text
  end
end
```

#### Section Helper Methods

Sections automatically generate the same helper methods as elements:

```ruby
class PageWithSections < Appom::Page
  section :header, HeaderSection, :class, 'header'
  sections :articles, ArticleSection, :class, 'article'
  
  # Generated methods for single section:
  # - header                  # Get the section instance
  # - has_header             # Check if section exists
  # - has_no_header          # Check if section doesn't exist
  # - header_params          # Get section find parameters
  
  # Generated methods for multiple sections:
  # - articles               # Get array of section instances
  # - has_articles          # Check if at least one exists
  # - has_no_articles       # Check if none exist
  # - get_all_articles      # Wait until not empty, return sections
  # - articles_params       # Get section find parameters
end
```

### Locator Strategies

Appom supports all Appium locator strategies:

```ruby
class LocatorExamples < Appom::Page
  # Mobile-specific strategies
  element :ios_element, :accessibility_id, 'my_element'
  element :android_element, :android_uiautomator, 'new UiSelector().text("Click")'
  element :ios_predicate, :ios_predicate, 'name == "my_element"'
  element :ios_chain, :ios_class_chain, '**/XCUIElementTypeButton[`name == "Submit"`]'
  element :android_viewtag, :android_viewtag, 'my_tag'
  
  # Web-compatible strategies  
  element :by_id, :id, 'element_id'
  element :by_class, :class, 'element_class'      # or :class_name
  element :by_css, :css, '.my-class > button'
  element :by_xpath, :xpath, '//button[@id="submit"]'
  element :by_name, :name, 'element_name'
  element :by_tag, :tag_name, 'button'
  element :by_link, :link_text, 'Click Here'
  element :by_partial_link, :partial_link_text, 'Click'
end
```

### Advanced Helper Methods

Appom includes comprehensive helper modules that provide additional functionality:

#### Element Interaction Helpers

```ruby
class InteractivePage < Appom::Page
  element :submit_button, :id, 'submit'
  element :text_field, :id, 'text_input'
  element :dynamic_content, :class, 'loading-content'
  
  def safe_submission(text)
    # Tap and wait for element to be enabled
    tap_and_wait(:submit_button, timeout: 10)
    
    # Get text with automatic retry
    current_text = get_text_with_retry(:text_field, retries: 3)
    
    # Wait for element to be visible then tap
    wait_and_tap(:submit_button)
    
    # Get attribute with fallback value
    status = get_attribute_with_fallback(:submit_button, 'aria-disabled', 'false')
    
    # Check if element contains specific text
    has_success = element_contains_text?(:status_message, 'Success')
    
    # Scroll to element and tap
    scroll_to_and_tap(:hidden_button, direction: :down)
  end
end
```

#### Advanced Wait Helpers

```ruby
class WaitingPage < Appom::Page
  element :loading_button, :id, 'load_btn'
  element :content_area, :class, 'content'
  
  def wait_for_interactions
    # Wait for element to be clickable (visible and enabled)
    wait_for_clickable(:loading_button, timeout: 15)
    
    # Wait for element text to match pattern
    wait_for_text_match(:content_area, 'Loading complete', exact: true, timeout: 20)
    wait_for_text_match(:status, /Ready|Complete/, exact: false)  # Regex support
    
    # Wait for element count to change
    initial_count = menu_items.count
    add_menu_item
    wait_for_element_count_change(:menu_items, from: initial_count)
    
    # Wait for any of multiple elements
    result = wait_for_any(:success_message, :error_message, timeout: 10)
    case result
    when :success_message
      puts "Operation succeeded"
    when :error_message  
      puts "Operation failed"
    end
  end
end
```

#### Performance Monitoring Helpers

```ruby
class MonitoredPage < Appom::Page
  element :search_button, :id, 'search'
  elements :search_results, :class, 'result'
  
  def timed_search(query)
    # Time any element operation
    time_element_operation(:search_button, 'click') do
      search_button.click
    end
    
    # Time complex operations
    Performance.time_operation('search_and_wait') do
      search_field.send_keys(query)
      search_button.click
      wait_for_search_results
    end
    
    # Get performance stats for specific elements
    search_stats = element_performance_stats(:search_button)
    puts "Search button performance: #{search_stats}"
    
    # Get overall performance summary
    summary = element_performance_stats
    puts "Page performance: #{summary}"
  end
end
```

#### Visual Testing Helpers

```ruby
class VisualPage < Appom::Page
  element :product_image, :id, 'product_img'
  element :header_banner, :class, 'banner'
  
  def visual_testing_example
    # Take screenshot with element highlighted
    screenshot_with_highlight(:product_image, filename: 'product_highlighted')
    
    # Visual regression test for current page
    result = visual_regression_test('product_page_layout', 
                                  element: product_image, 
                                  threshold: 0.05)
    
    # Wait for visual stability (useful for animations)
    wait_for_visual_stability(:header_banner, duration: 2, check_interval: 0.5)
    wait_for_visual_stability(duration: 3)  # Wait for entire page stability
    
    puts "Visual test passed: #{result[:passed]}"
  end
end
```

#### Element State Tracking Helpers

```ruby
class StateTrackingPage < Appom::Page
  element :dynamic_status, :id, 'status'
  element :progress_bar, :class, 'progress'
  
  def track_element_changes
    # Start tracking an element's state changes
    track_element_state(:dynamic_status, context: { test: 'status_monitoring' })
    
    # Perform actions that change element state
    start_process_button.click
    
    # Wait for element state to change
    wait_for_element_state_change(:dynamic_status, 
                                expected_changes: { text: 'Complete' },
                                timeout: 30)
    
    # Get current state of tracked element
    current_state = element_current_state(:dynamic_status)
    puts "Status element state: #{current_state}"
    
    # Track progress bar changes
    track_element_state(:progress_bar)
    wait_for_element_state_change(:progress_bar,
                                expected_changes: { 'aria-valuenow' => '100' })
  end
end
```

#### Debug Helpers

```ruby
class DebuggablePage < Appom::Page
  element :problematic_element, :xpath, '//div[@class="complex"]'
  
  def debug_page_issues
    begin
      problematic_element.click
    rescue => e
      # Capture screenshot on failure
      capture_screenshot_on_failure('problematic_element_click', e)
      
      # Dump page source for analysis
      source_file = dump_page_source('debug_page_source')
      puts "Page source saved: #{source_file}"
      
      # Get detailed info about all matching elements
      element_info = debug_elements_info(:xpath, '//div[@class="complex"]')
      element_info.each do |info|
        puts "Element #{info[:index]}: #{info}"
      end
      
      raise e
    end
  end
end
```

### Retry Mechanisms

Appom provides robust retry mechanisms for handling flaky elements:

```ruby
class RetryablePage < Appom::Page
  element :flaky_button, :id, 'unstable_btn'
  element :dynamic_field, :class, 'dynamic'
  
  def reliable_interactions
    # Find element with retry and exponential backoff
    element = find_with_retry(:flaky_button, 
                            max_attempts: 5,
                            base_delay: 0.5,
                            backoff_multiplier: 2)
    
    # Interact with element using retry
    interact_with_retry(:flaky_button, :tap,
                       max_attempts: 3,
                       base_delay: 1,
                       retry_on: [Selenium::WebDriver::Error::ElementNotInteractableError])
    
    # Send keys with retry
    interact_with_retry(:dynamic_field, :send_keys,
                       text: 'Hello World',
                       max_attempts: 3)
    
    # Custom retry with conditional logic
    retry_on_condition(max_attempts: 5, delay: 0.5) do
      element = flaky_button
      element.displayed? && element.enabled?
    end
  end
  
  # Custom retry with error handling
  def safe_element_interaction
    retry_with_recovery(max_attempts: 3) do
      flaky_button.click
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      # Refresh page object state
      refresh_page
      retry
    rescue Selenium::WebDriver::Error::ElementNotInteractableError => e
      # Wait and try again
      sleep(1)
      raise e  # Re-raise to trigger retry
    end
  end
end
```

## Best Practices

### 1. Page Object Organization

```ruby
# Keep page objects focused and single-responsibility
class LoginPage < Appom::Page
  element :email, :id, 'email'
  element :password, :id, 'password'
  element :submit, :id, 'submit'
  
  def login(credentials)
    fill_form(credentials)
    submit_form
    await_navigation
  end
  
  private
  
  def fill_form(credentials)
    self.email = credentials[:email]
    self.password = credentials[:password]
  end
  
  def submit_form
    submit.click
  end
  
  def await_navigation
    wait_for_no_element(:submit)
  end
end
```

### 2. Element Naming

```ruby
# Use descriptive, semantic names
class GoodNamingPage < Appom::Page
  element :email_input, :id, 'email'
  element :password_input, :id, 'password'
  element :login_button, :id, 'submit'
  element :error_message, :class, 'error'
  element :forgot_password_link, :link_text, 'Forgot Password?'
end
```

### 3. Wait Strategy

```ruby
# Use appropriate waiting strategies
class WellWaitingPage < Appom::Page
  element :dynamic_content, :id, 'content'
  
  def wait_for_content_load
    # Wait for element presence
    wait_for_element(:dynamic_content)
    
    # Wait for element to be interactive
    wait_until { dynamic_content.enabled? }
    
    # Wait for visual stability
    wait_for_visual_stability(element: dynamic_content)
  end
end
```

### 4. Error Handling

```ruby
class RobustPage < Appom::Page
  def safe_navigation
    with_performance_monitoring('navigation') do
      with_error_handling do
        navigation_button.click
        wait_for_page_load
      end
    end
  rescue Appom::TimeoutError
    log_warning "Navigation timed out, trying alternative method"
    alternative_navigation
  rescue Appom::ElementNotFoundError => e
    log_error "Navigation failed: #{e.message}"
    take_debug_screenshot
    raise
  end
end
```

## Troubleshooting

### Common Issues

1. **Element Not Found**
```ruby
# Debug element location issues
begin
  element.click
rescue Appom::ElementNotFoundError => e
  puts "Available elements: #{page.all_elements}"
  puts "Page source: #{page.page_source}"
  take_screenshot('debug_element_not_found.png')
end
```

2. **Timing Issues**
```ruby
# Increase wait times for slow apps
Appom.configure do |config|
  config.max_wait_time = 60
  config.smart_wait_timeout = 45
end

# Use explicit waits
wait_until(timeout: 30) { element.displayed? }
```

3. **Performance Issues**
```ruby
# Disable caching for debugging
element :problematic_element, :id, 'element', cache: false

# Monitor performance
Appom::Performance.enable_detailed_logging
```

### Debugging Tools

```ruby
# Take debug screenshot
Appom::Screenshot.debug_capture('debug_screen.png')

# Dump element cache
puts Appom::ElementCache.debug_info

# Get performance metrics
metrics = Appom::Performance.get_detailed_metrics
puts "Performance issues: #{metrics[:slow_operations]}"

# Element state debugging
state_info = Appom::ElementState.debug_element(element)
puts "Element state: #{state_info}"
```

### Logging for Troubleshooting

```ruby
# Enable verbose logging
Appom.configure do |config|
  config.log_level = :debug
  config.log_element_interactions = true
  config.log_wait_operations = true
  config.log_performance_details = true
end

# Custom debugging
class DebuggingPage < Appom::Page
  def debug_element_state(element_name)
    element = send(element_name)
    
    log_debug "Element: #{element_name}"
    log_debug "Present: #{element.present?}"
    log_debug "Displayed: #{element.displayed?}"
    log_debug "Enabled: #{element.enabled?}"
    log_debug "Location: #{element.location}"
    log_debug "Size: #{element.size}"
    log_debug "Text: #{element.text}"
  end
end
```

This comprehensive documentation covers all major features and capabilities of Appom. For additional help, refer to the API documentation or check the project's GitHub repository for the latest updates and examples.