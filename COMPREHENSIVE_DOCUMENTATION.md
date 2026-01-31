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
11. [Configuration](#configuration)
12. [Error Handling](#error-handling)
13. [Logging](#logging)
14. [Advanced Features](#advanced-features)
15. [Best Practices](#best-practices)
16. [Troubleshooting](#troubleshooting)

## Introduction

**Appom** is a comprehensive Page Object Model framework for mobile application testing using Appium. It provides a clean, semantic DSL for describing mobile applications with enhanced features including performance monitoring, visual testing, intelligent waiting, element state tracking, and robust error handling.

### Key Benefits

- **Semantic DSL**: Write tests that read like natural language
- **Intelligent Waiting**: Smart wait strategies that adapt to your app's behavior
- **Performance Monitoring**: Track and optimize test execution performance
- **Visual Testing**: Automated visual regression testing capabilities
- **Element State Tracking**: Monitor element changes over time
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
  
  def search_for(term)
    search_box.set term
    search_box.send_keys(:return)
  end
end
```

### Element Definition Syntax

```ruby
# Basic element definition
element :name, :locator_strategy, 'locator_value'

# With options
element :button, :id, 'submit', {
  visible: true,
  timeout: 10,
  cache: false
}

# Multiple elements
elements :list_items, :class, 'item'

# Expected elements (will wait for presence)
expected_element :welcome_message, :id, 'welcome'
```

## Element Management

### Element Interaction

```ruby
# Text input
email_field.set 'user@example.com'
email_field.clear

# Clicking
button.click
button.double_click
button.long_press

# Getting information
text = element.text
value = element.attribute('value')
location = element.location
size = element.size
enabled = element.enabled?
displayed = element.displayed?

# Advanced interactions
element.swipe_up
element.swipe_down
element.swipe_left
element.swipe_right
```

### Element Validation

```ruby
class SignupPage < Appom::Page
  element :email_field, :id, 'email'
  
  # Validate element state
  def email_valid?
    validate_element(email_field) do |el|
      el.displayed? && 
      el.enabled? && 
      el.attribute('value').include?('@')
    end
  end
  
  # Element presence checks
  def has_email_field?
    email_field.present?
  end
  
  def email_field_visible?
    email_field.visible?
  end
end
```

### Element Caching

Appom provides intelligent element caching to improve performance:

```ruby
# Enable caching (default)
element :cached_button, :id, 'button', cache: true

# Disable caching for dynamic elements
element :dynamic_content, :xpath, '//div[@id="dynamic"]', cache: false

# Manual cache management
ElementCache.clear_all
ElementCache.clear_for_page(self)
ElementCache.size  # Get cache statistics
```

## Waiting Strategies

### Basic Waiting

```ruby
# Wait for element to be present
wait_for_element(:login_button, timeout: 10)

# Wait for condition
wait_until(timeout: 15) { page_loaded? }

# Wait for element to disappear
wait_for_no_element(:loading_spinner)
```

### Smart Waiting

Appom includes intelligent waiting that adapts to your application:

```ruby
# Smart wait automatically adjusts timing
smart_wait_for(:complex_element) do |element|
  element.displayed? && element.enabled?
end

# Configure smart wait behavior
Appom.configure do |config|
  config.smart_wait_enabled = true
  config.smart_wait_timeout = 30
  config.smart_wait_interval = 0.5
  config.smart_wait_retry_limit = 3
end
```

### Advanced Waiting

```ruby
class CheckoutPage < Appom::Page
  element :payment_form, :id, 'payment'
  
  def wait_for_payment_processing
    # Wait with custom conditions
    wait_until(
      timeout: 60,
      message: 'Payment processing timed out'
    ) do
      !payment_form.attribute('class').include?('processing')
    end
  end
  
  # Wait for visual stability (useful for animations)
  def wait_for_animation_complete
    wait_for_visual_stability(element: payment_form, duration: 2)
  end
end
```

## Performance Monitoring

Appom provides comprehensive performance tracking:

### Basic Performance Tracking

```ruby
# Time individual operations
result = Appom::Performance.time_operation('login_process') do
  login_page.login('user@example.com', 'password')
end

puts "Login took #{result[:duration]}ms"
```

### Detailed Performance Monitoring

```ruby
class LoginPage < Appom::Page
  def login_with_monitoring(email, password)
    Appom::Performance.start_session('user_login')
    
    Appom::Performance.mark_milestone('form_fill_start')
    email_field.set email
    password_field.set password
    Appom::Performance.mark_milestone('form_fill_complete')
    
    Appom::Performance.mark_milestone('submit_start')
    login_button.click
    Appom::Performance.mark_milestone('submit_complete')
    
    wait_for_next_page
    Appom::Performance.mark_milestone('navigation_complete')
    
    report = Appom::Performance.end_session
    puts "Login performance: #{report}"
  end
end
```

### Performance Reporting

```ruby
# Get detailed performance metrics
metrics = Appom::Performance.get_metrics
puts "Average operation time: #{metrics[:average_duration]}ms"
puts "Total operations: #{metrics[:operation_count]}"
puts "Slowest operation: #{metrics[:slowest_operation]}"

# Generate performance report
report_path = Appom::Performance.generate_report
puts "Performance report saved to: #{report_path}"

# Export metrics to JSON
Appom::Performance.export_metrics('performance_data.json')
```

## Visual Testing

Appom includes powerful visual regression testing capabilities:

### Basic Visual Testing

```ruby
# Initialize visual test helper
visual = Appom::Visual::TestHelpers.new(
  baseline_dir: 'test/visual_baselines',
  results_dir: 'test/visual_results',
  threshold: 0.01  # 1% difference threshold
)

# Take visual regression test
result = visual.visual_regression_test('login_screen')
puts "Visual test passed: #{result[:passed]}"
```

### Element-Specific Visual Testing

```ruby
class ProductPage < Appom::Page
  element :product_image, :id, 'product_img'
  
  def verify_product_image
    # Compare specific element with baseline
    result = Appom::Visual.compare_element_visuals(
      product_image, 
      'product_image_baseline'
    )
    
    unless result[:passed]
      puts "Visual difference detected: #{result[:differences]}"
    end
    
    result[:passed]
  end
end
```

### Advanced Visual Testing

```ruby
# Take annotated screenshots
annotations = [
  { type: :rectangle, x: 100, y: 200, width: 200, height: 100, color: 'red' },
  { type: :text, x: 150, y: 150, text: 'Key Area', color: 'blue' }
]

screenshot_path = visual.take_visual_screenshot(
  'annotated_screen', 
  annotations: annotations
)

# Visual diff between two images
diff_result = visual.visual_diff(
  'baseline_image.png',
  'current_image.png',
  'output_diff.png'
)

# Highlight specific elements
highlighted_path = visual.highlight_element(
  product_image,
  color: 'red',
  thickness: 3
)

# Wait for visual stability (useful for animations)
stable = visual.wait_for_visual_stability(
  duration: 3,
  check_interval: 0.5
)
```

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