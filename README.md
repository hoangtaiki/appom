# Appom
[![Gem Version](https://badge.fury.io/rb/appom.svg)](http://badge.fury.io/rb/appom)
[![Build Status](https://github.com/hoangtaiki/appom/workflows/CI/badge.svg)](https://github.com/hoangtaiki/appom/actions)
[![Coverage](https://codecov.io/gh/hoangtaiki/appom/branch/main/graph/badge.svg)](https://codecov.io/gh/hoangtaiki/appom)

A Page Object Model framework for Appium with enhanced error handling, logging, and helper methods.

Appom provides a simple, clean and semantic DSL for describing mobile applications. It implements the Page Object Model pattern on top of Appium with modern Ruby features and comprehensive error handling.

## Features

- 🎯 **Clean DSL** - Simple element and section definitions
- 🔄 **Smart Retry Logic** - Automatic retry with exponential backoff
- 📊 **Structured Logging** - Comprehensive logging with configurable levels
- 🛡️ **Error Handling** - Detailed exceptions with context
- ✅ **Element Validation** - Comprehensive validation for element definitions
- 🔍 **Debug Helpers** - Screenshots, page source dumps, and element inspection
- 📱 **Cross-Platform** - Support for iOS and Android

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'appom'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install appom

## Quick Start

### 1. Register Appium Driver

```ruby
require 'appom'

# Register the Appium driver
Appom.register_driver do
  options = {
    appium_lib: {
      server_url: 'http://localhost:4723/wd/hub'
    },
    caps: {
      platformName: 'iOS',
      deviceName: 'iPhone 13',
      app: '/path/to/your/app.ipa'
    }
  }
  Appium::Driver.new(options, false)
end

# Configure global settings
Appom.configure do |config|
  config.max_wait_time = 30
end

# Optional: Configure logging
Appom.configure_logging(level: :info, output: STDOUT)
```

### 2. Define Page Objects

```ruby
class LoginPage < Appom::Page
  # Basic element definitions
  element :email_field, :accessibility_id, 'email_text_field'
  element :password_field, :accessibility_id, 'password_text_field'
  element :login_button, :accessibility_id, 'login_button'
  element :error_message, :xpath, '//UILabel[@name="error"]'
  
  # Elements with additional options
  element :submit_button, :id, 'submit_btn', visible: true
  elements :menu_items, :class, 'MenuItem'
  
  # Page-specific methods using helpers
  def login(email, password)
    # Using helper methods with retry
    interact_with_retry(:email_field, :clear)
    interact_with_retry(:email_field, :send_keys, text: email)
    
    interact_with_retry(:password_field, :clear) 
    interact_with_retry(:password_field, :send_keys, text: password)
    
    # Tap with automatic wait
    tap_and_wait(:login_button)
  end
  
  def login_with_validation(email, password)
    login(email, password)
    
    # Wait for either success or error
    result = wait_for_any(:success_indicator, :error_message, timeout: 10)
    
    if result == :error_message
      error_text = get_text_with_retry(:error_message)
      raise "Login failed: #{error_text}"
    end
    
    result == :success_indicator
  end
end

class HomePage < Appom::Page
  # Section definitions for complex UI components
  section :header, HeaderSection, :id, 'header_container'
  sections :product_cards, ProductCardSection, :class, 'ProductCard'
  
  def search_for_product(query)
    header.search_for(query)
    wait_for_products_to_load
  end
  
  private
  
  def wait_for_products_to_load
    wait_for_text_in_element(:loading_indicator, 'Loading...', timeout: 5)
    wait_for_disappear(:loading_indicator, timeout: 10)
  end
end

class HeaderSection < Appom::Section
  element :search_field, :accessibility_id, 'search_input'
  element :search_button, :accessibility_id, 'search_button'
  element :profile_button, :id, 'profile_btn'
  
  def search_for(query)
    # Use retry methods for flaky elements
    get_text_with_retry(:search_field) # Ensure field is ready
    interact_with_retry(:search_field, :send_keys, text: query)
    tap_and_wait(:search_button)
  end
end

class ProductCardSection < Appom::Section
  element :title, :xpath, './/UILabel[@name="title"]'
  element :price, :xpath, './/UILabel[@name="price"]'
  element :add_button, :xpath, './/UIButton[@name="add_to_cart"]'
  
  def add_to_cart
    scroll_to_and_tap(:add_button) # Helper method with scrolling
  end
  
  def product_info
    {
      title: get_text_with_retry(:title),
      price: get_text_with_retry(:price)
    }
  end
end
```

### 3. Use in Tests

```ruby
# RSpec example
RSpec.describe 'User Login' do
  let(:login_page) { LoginPage.new }
  let(:home_page) { HomePage.new }
  
  before(:each) do
    Appom.start_driver
  end
  
  after(:each) do
    Appom.reset_driver
  end
  
  it 'logs in successfully' do
    # Use page object methods
    expect(login_page.login_with_validation('user@example.com', 'password')).to be true
    
    # Use built-in element state checking
    expect(home_page).to have_header
    expect(home_page.header).to have_profile_button
  end
  
  it 'handles login errors gracefully' do
    expect {
      login_page.login_with_validation('invalid@email.com', 'wrong_password')
    }.to raise_error(/Login failed/)
  end
end

# Cucumber integration (automatic driver management)
Given(/^I am on the login page$/) do
  @login_page = LoginPage.new
  expect(@login_page).to have_email_field
end

When(/^I login with "([^"]*)" and "([^"]*)"$/) do |email, password|
  @login_page.login(email, password)
end

Then(/^I should see the home page$/) do
  @home_page = HomePage.new
  expect(@home_page).to have_header
end
```

## Advanced Features

### Error Handling & Debugging

```ruby
class MyPage < Appom::Page
  element :tricky_element, :id, 'sometimes_missing'
  
  def interact_with_tricky_element
    # Automatic screenshot on failure
    begin
      tap_and_wait(:tricky_element)
    rescue Appom::ElementNotFoundError => e
      take_debug_screenshot('element_not_found')
      dump_page_source('error_state')
      raise e
    end
  end
  
  def debug_page_elements
    # Get detailed info about all elements
    debug_elements_info(:class, 'UIButton')
  end
end
```

### Custom Retry Configuration

```ruby
class FlakeyPage < Appom::Page  
  element :unstable_element, :id, 'flaky_element'
  
  def interact_with_custom_retry
    # Custom retry with specific conditions
    find_with_retry(:unstable_element,
      max_attempts: 5,
      base_delay: 1.0,
      backoff_multiplier: 2.0,
      retry_on: [Appom::ElementNotFoundError],
      on_retry: ->(error, attempt, delay) {
        log_warn "Attempt #{attempt} failed: #{error.message}, retrying in #{delay}s"
        take_debug_screenshot("retry_attempt_#{attempt}")
      }
    )
  end
end
```

### Logging Configuration

```ruby
# Configure detailed logging
Appom.configure_logging(
  level: :debug,
  output: File.open('appom.log', 'a')
)

# Custom logger
require 'logger'
custom_logger = Logger.new($stdout)
custom_logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime}] #{severity}: #{msg}\n"
end

Appom.configure_logging(custom_logger: custom_logger)
```

## Element Locator Strategies

Appom supports all Appium locator strategies:

```ruby
class ExamplePage < Appom::Page
  # iOS-specific
  element :ios_element, :ios_predicate, 'name == "Submit"'
  element :ios_chain, :ios_class_chain, '**/UIButton[`name == "Submit"`]'
  
  # Android-specific  
  element :android_element, :android_uiautomator, 'new UiSelector().text("Submit")'
  element :android_view, :android_viewtag, 'submit_button'
  
  # Cross-platform
  element :by_id, :id, 'submit_button'
  element :by_class, :class_name, 'UIButton'
  element :by_xpath, :xpath, '//UIButton[@name="Submit"]'
  element :by_accessibility, :accessibility_id, 'submit_button'
  
  # With additional filtering
  element :visible_button, :class_name, 'UIButton', visible: true
  element :button_with_text, :class_name, 'UIButton', text: 'Submit'
end
```

## Built-in Element Methods

For every element defined, Appom automatically creates helper methods:

```ruby
class MyPage < Appom::Page
  element :submit_button, :id, 'submit'
  elements :menu_items, :class, 'MenuItem'
end

page = MyPage.new

# Element access
page.submit_button          # Get the element
page.menu_items            # Get array of elements

# State checking  
page.has_submit_button?     # Check if element exists
page.has_no_submit_button?  # Check if element doesn't exist

# State waiting
page.submit_button_enable   # Wait for element to be enabled
page.submit_button_disable  # Wait for element to be disabled

# Bulk operations
page.get_all_menu_items     # Get all menu items (with wait)

# Parameters
page.submit_button_params   # Get the locator parameters used
```

## Error Types

Appom provides detailed error information:

```ruby
begin
  page.missing_element
rescue Appom::ElementNotFoundError => e
  puts e.message                    # "Element not found with selector: id, missing_button within 30s"
  puts e.context[:selector]         # "id, missing_button"  
  puts e.context[:timeout]          # 30
  puts e.detailed_message           # Full context dump
end

# Other error types:
# Appom::ElementStateError - Element found but in wrong state
# Appom::WaitError - Wait condition not met
# Appom::DriverError - Driver-related issues  
# Appom::ConfigurationError - Invalid configuration
# Appom::InvalidElementError - Invalid element definition
```

## Testing

Run the test suite:

```bash
bundle exec rspec
```

Run with coverage:

```bash
bundle exec rake test_with_coverage
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`bundle exec rake`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Create a Pull Request

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.