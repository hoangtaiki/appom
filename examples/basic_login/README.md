# Basic Login Example 🔐

A simple example demonstrating fundamental Appom concepts through a login flow.

## 🎯 What You'll Learn

- Creating page objects with Appom
- Element definitions and interactions
- Basic test structure with RSpec
- Error handling and debugging
- Configuration setup

## 🏗️ Project Structure

```
basic_login/
├── README.md           # This file
├── Gemfile             # Dependencies
├── spec/              
│   ├── spec_helper.rb  # Test configuration
│   └── login_spec.rb   # Login tests
├── page_objects/
│   ├── login_page.rb   # Login page object
│   └── home_page.rb    # Home page object
└── config/
    └── appium_config.rb # Appium configuration
```

## 🚀 Quick Start

1. **Install dependencies:**
   ```bash
   bundle install
   ```

2. **Start Appium server:**
   ```bash
   appium
   ```

3. **Run tests:**
   ```bash
   bundle exec rspec
   ```

## 📱 App Requirements

This example works with any app that has:
- Email/username input field
- Password input field  
- Login button
- Success/error feedback

Update the element selectors in `page_objects/` to match your app.

## 🧪 Test Scenarios

The example includes tests for:

✅ **Successful login** - Valid credentials  
✅ **Failed login** - Invalid credentials  
✅ **Empty fields** - Missing email/password  
✅ **Network error** - Connection issues  
✅ **UI validation** - Element visibility

## 🔧 Configuration

Edit `config/appium_config.rb` for your setup:

```ruby
# iOS Configuration
CAPS = {
  platformName: 'iOS',
  deviceName: 'iPhone 15',
  app: '/path/to/your/app.ipa',
  automationName: 'XCUITest'
}

# Android Configuration  
CAPS = {
  platformName: 'Android',
  deviceName: 'Pixel_7_API_33',
  app: '/path/to/your/app.apk',
  automationName: 'UiAutomator2'
}
```

## 📚 Key Concepts Demonstrated

### 1. Page Object Pattern
```ruby
class LoginPage < Appom::Page
  element :email_field, :accessibility_id, 'email_input'
  element :password_field, :accessibility_id, 'password_input'
  element :login_button, :accessibility_id, 'login_button'
  
  def login(email, password)
    email_field.set(email)
    password_field.set(password)
    login_button.tap
  end
end
```

### 2. Smart Waiting
```ruby
# Wait for element to appear
login_page.wait_for_login_button

# Wait for navigation  
expect(home_page).to have_welcome_message
```

### 3. Error Handling
```ruby
begin
  login_page.login('invalid@email.com', 'wrong')
rescue Appom::ElementNotFoundError => e
  puts "Login failed: #{e.message}"
end
```

## 🎨 Customization

**For your app:**
1. Update element selectors in `page_objects/`
2. Modify app capabilities in `config/appium_config.rb`
3. Adjust test scenarios in `spec/login_spec.rb`
4. Add new page objects as needed

## 🔍 Debugging Tips

**Element not found?**
```ruby
# Debug element info
login_page.debug_elements_info(:class, 'UIButton')

# Take screenshot
login_page.take_debug_screenshot('debug_login')

# Dump page source
login_page.dump_page_source('login_page_source')
```

**Test failing?**
- Check element selectors with Appium Inspector
- Verify app state before test runs
- Add explicit waits for slow elements
- Review Appium server logs

## 🚀 Next Steps

After mastering this example:

1. **Try the e-commerce example** - More complex workflows
2. **Add visual testing** - Screenshot comparisons
3. **Implement data-driven tests** - Multiple user scenarios
4. **Add performance monitoring** - Track test execution
5. **Create your own examples** - Real app automation!

## 🤝 Need Help?

- 📖 [Full Documentation](../../Documentation.md)
- 💬 [GitHub Discussions](https://github.com/hoangtaiki/appom/discussions)
- 🐛 [Report Issues](https://github.com/hoangtaiki/appom/issues)

Happy testing! 🎉