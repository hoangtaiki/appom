<div align="center">

# 📱 Appom

**The Modern Page Object Model Framework for Mobile Test Automation**

[![Gem Version](https://badge.fury.io/rb/appom.svg)](http://badge.fury.io/rb/appom)
[![Build Status](https://github.com/hoangtaiki/appom/workflows/CI/badge.svg)](https://github.com/hoangtaiki/appom/actions)
[![Coverage](https://codecov.io/gh/hoangtaiki/appom/branch/master/graph/badge.svg)](https://codecov.io/gh/hoangtaiki/appom)
[![Ruby Version](https://img.shields.io/badge/Ruby-3.2.2-red)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Downloads](https://img.shields.io/gem/dt/appom.svg)](https://rubygems.org/gems/appom)

*Write mobile tests that are maintainable, readable, and reliable*

[Quick Start](#-quick-start) • [Documentation](Documentation.md) • [Examples](#-examples) • [Contributing](#-contributing)

</div>

---

## ✨ Why Appom?

Tired of flaky mobile tests that break every release? **Appom** transforms mobile test automation with:

```ruby
# Traditional approach 😢
driver.find_element(:id, 'login_btn').click
sleep(2) # Hope the page loads...
driver.find_element(:xpath, '//input[@type="email"]').send_keys('user@test.com')

# Appom way 🎉
login_page.login('user@test.com', 'password')
expect(home_page).to have_dashboard
```

## 🚀 Key Features

<table>
  <tr>
    <td>🎯 <strong>Smart Page Objects</strong></td>
    <td>Semantic DSL that reads like natural language</td>
  </tr>
  <tr>
    <td>🔄 <strong>Intelligent Retry</strong></td>
    <td>Auto-retry with exponential backoff for flaky elements</td>
  </tr>
  <tr>
    <td>📊 <strong>Performance Monitoring</strong></td>
    <td>Track test performance and identify bottlenecks</td>
  </tr>
  <tr>
    <td>🎨 <strong>Visual Testing</strong></td>
    <td>Automated visual regression testing built-in</td>
  </tr>
  <tr>
    <td>🛡️ <strong>Robust Error Handling</strong></td>
    <td>Detailed diagnostics with screenshots and context</td>
  </tr>
  <tr>
    <td>📱 <strong>Cross-Platform</strong></td>
    <td>Single codebase for iOS and Android</td>
  </tr>
</table>

## 📦 Installation

```bash
gem install appom
```

Or add to your `Gemfile`:

```ruby
gem 'appom'
```

## ⚡ Quick Start

### 1. Initialize Appom

```ruby
require 'appom'

Appom.register_driver do
  Appium::Driver.new({
    caps: {
      platformName: 'iOS',
      deviceName: 'iPhone 15',
      app: '/path/to/your/app.ipa'
    },
    appium_lib: { server_url: 'http://localhost:4723/wd/hub' }
  })
end
```

### 2. Create Page Objects

```ruby
class LoginPage < Appom::Page
  element :email, :accessibility_id, 'email_field'
  element :password, :accessibility_id, 'password_field'
  element :login_btn, :accessibility_id, 'login_button'
  
  def login(email, password)
    self.email.set(email)
    self.password.set(password)
    login_btn.tap
  end
end
```

### 3. Write Tests

```ruby
RSpec.describe 'Login Flow' do
  it 'logs user in successfully' do
    login_page = LoginPage.new
    login_page.login('test@example.com', 'password')
    
    expect(HomePage.new).to have_welcome_message
  end
end
```

**That's it!** No more `sleep()`, no more flaky selectors, no more mysterious failures.

## 🎯 Examples

<details>
<summary><strong>Advanced Page Object with Sections</strong></summary>

```ruby
class ShoppingPage < Appom::Page
  section :header, HeaderSection, :id, 'header'
  sections :products, ProductSection, :class, 'product-card'
  
  def add_product_to_cart(product_name)
    product = products.find { |p| p.name.text == product_name }
    product.add_to_cart
    wait_for_cart_update
  end
end

class ProductSection < Appom::Section
  element :name, :class, 'product-name'
  element :price, :class, 'product-price'
  element :add_btn, :class, 'add-to-cart-btn'
  
  def add_to_cart
    scroll_to_and_tap(:add_btn)
  end
end
```

</details>

<details>
<summary><strong>Smart Waiting & Retry Logic</strong></summary>

```ruby
class PaymentPage < Appom::Page
  element :card_field, :id, 'card_number'
  element :submit_btn, :id, 'submit_payment'
  
  def process_payment(card_number)
    # Auto-retry for flaky elements
    interact_with_retry(:card_field, :send_keys, text: card_number)
    
    # Wait for specific conditions
    tap_and_wait(:submit_btn)
    wait_for_any(:success_message, :error_message, timeout: 30)
  end
end
```

</details>

<details>
<summary><strong>Visual Testing Integration</strong></summary>

```ruby
class ProductPage < Appom::Page
  def verify_product_display
    # Automatic visual regression testing
    take_visual_snapshot('product_page')
    compare_visual_baseline('product_page', threshold: 0.95)
  end
end
```

</details>

## 📚 Documentation

- **[Complete Documentation](Documentation.md)** - Comprehensive guide with advanced features
- **[API Reference](https://rubydoc.info/gems/appom)** - Detailed API documentation  
- **[Best Practices](Documentation.md#best-practices)** - Testing patterns and conventions
- **[Troubleshooting](Documentation.md#troubleshooting)** - Common issues and solutions

---

<div align="center">
  
**Made with ❤️ by the mobile testing community**

[⬆ Back to top](#-appom)

</div>