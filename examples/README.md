# Appom Examples 📱

This directory contains practical examples of using Appom for mobile test automation.

## 🏗️ Project Structure

```
examples/
├── basic_login/           # Simple login flow example
├── ecommerce_app/         # Complex e-commerce testing
├── social_media/          # Social media app automation
├── banking_app/           # Secure banking app testing
├── cross_platform/        # iOS + Android same tests
└── performance_testing/   # Performance monitoring examples
```

## 🚀 Quick Start

Each example includes:
- **README.md** - Setup instructions and overview
- **Gemfile** - Required dependencies
- **spec/** - RSpec test files
- **features/** - Cucumber features (where applicable)
- **page_objects/** - Reusable page object classes
- **config/** - Environment-specific configurations

## 💡 Example Applications

### 1. Basic Login (`basic_login/`)
Perfect for beginners. Shows:
- Simple page objects
- Element interactions
- Basic assertions
- Error handling

### 2. E-commerce App (`ecommerce_app/`)
Advanced patterns including:
- Product catalog navigation
- Shopping cart operations
- Checkout flow automation
- Multi-screen workflows

### 3. Social Media (`social_media/`)
Demonstrates:
- Dynamic content handling
- Infinite scroll testing
- Image/media interactions
- Push notification testing

### 4. Banking App (`banking_app/`)
Security-focused testing:
- Secure login flows
- Transaction verification
- Sensitive data handling
- Compliance testing

### 5. Cross Platform (`cross_platform/`)
Same tests, multiple platforms:
- Shared page objects
- Platform-specific elements
- Configuration management
- Parallel execution

### 6. Performance Testing (`performance_testing/`)
Performance monitoring:
- Response time tracking
- Memory usage monitoring
- Visual performance testing
- Benchmark comparisons

## 🏃‍♂️ Running Examples

```bash
cd examples/basic_login
bundle install
bundle exec rspec
```

## 🤝 Contributing Examples

Have a great Appom example? We'd love to include it! 

1. Create a new directory under `examples/`
2. Include complete working code
3. Add comprehensive README
4. Submit a Pull Request

## 📚 Learning Path

**New to Appom?** Follow this progression:
1. `basic_login/` - Learn fundamentals
2. `ecommerce_app/` - Understand complex flows
3. `cross_platform/` - Master multi-platform testing
4. `performance_testing/` - Advanced monitoring
5. Create your own! 🚀