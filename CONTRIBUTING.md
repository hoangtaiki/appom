# Contributing to Appom 🚀

First off, thank you for considering contributing to Appom! 🎉 It's people like you who make Appom such a great tool for mobile test automation.

## 🌟 Ways to Contribute

- **🐛 Report bugs** - Found something broken? Let us know!
- **💡 Suggest features** - Have an idea to make Appom better?
- **📝 Improve documentation** - Help others learn Appom
- **💻 Submit code** - Fix bugs or implement new features
- **🧪 Write tests** - Help us maintain quality
- **🎨 Share examples** - Show how you use Appom

## 🚀 Quick Start for Contributors

1. **Fork** the repository
2. **Clone** your fork: `git clone https://github.com/YOUR-USERNAME/appom.git`
3. **Install** dependencies: `bundle install`
4. **Create** a feature branch: `git checkout -b my-awesome-feature`
5. **Make** your changes
6. **Run tests**: `bundle exec rake`
7. **Submit** a Pull Request

## 🧪 Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with coverage
COVERAGE=true bundle exec rspec

# Run specific test file
bundle exec rspec spec/page_spec.rb

# Run with specific tag
bundle exec rspec --tag focus
```

## 📋 Code Style Guidelines

We use RuboCop for code style enforcement:

```bash
# Check style
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -A
```

### Ruby Style Rules

- Use 2 spaces for indentation
- Keep lines under 120 characters
- Use meaningful variable and method names
- Add documentation for public methods
- Follow Ruby naming conventions

### Test Requirements

- Write RSpec tests for new features
- Maintain test coverage above 85%
- Use descriptive test names
- Mock external dependencies
- Test both success and failure scenarios

## 🎯 Pull Request Guidelines

### Before Submitting

- [ ] Tests pass locally (`bundle exec rake`)
- [ ] Code follows style guidelines (`bundle exec rubocop`)
- [ ] Documentation is updated if needed
- [ ] Changelog is updated for notable changes
- [ ] Commit messages are clear and descriptive

### PR Template

```markdown
## Description
Brief description of the changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tests added/updated
- [ ] Manual testing performed
- [ ] Edge cases considered

## Checklist
- [ ] Code follows project style
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or properly documented)
```

## 🐛 Bug Reports

When filing a bug report, include:

1. **Appom version** you're using
2. **Platform** (iOS/Android)
3. **Device/emulator** details
4. **Steps to reproduce**
5. **Expected vs actual behavior**
6. **Code sample** (minimal reproduction)
7. **Error messages/logs**

## 💡 Feature Requests

For feature requests, please provide:

1. **Problem statement** - What problem does this solve?
2. **Proposed solution** - How should it work?
3. **Code example** - How would you use it?
4. **Priority level** - How important is this to you?

## 🏗️ Architecture Overview

```
lib/appom/
├── page.rb           # Base Page class
├── section.rb        # Base Section class  
├── element_*.rb      # Element management
├── helpers.rb        # Utility methods
├── performance.rb    # Performance monitoring
├── visual.rb         # Visual testing
├── smart_wait.rb     # Smart waiting strategies
└── configuration.rb  # Configuration management
```

## 🧪 Testing Philosophy

We believe in:

- **Test-Driven Development** - Write tests first when possible
- **Comprehensive Coverage** - Test edge cases and error conditions
- **Fast Feedback** - Tests should run quickly
- **Clear Assertions** - Tests should be easy to understand
- **Minimal Mocking** - Use real objects when practical

## 📚 Documentation Standards

- **Public methods** must have YARD documentation
- **Complex logic** should have inline comments
- **Examples** should be realistic and runnable
- **README updates** for user-facing changes
- **Changelog entries** for all notable changes

## 🎉 Recognition

Contributors are recognized in:

- **CHANGELOG.md** - For notable contributions
- **README.md** - Major feature contributors
- **GitHub Releases** - Thank you notes
- **Twitter shoutouts** - Community recognition

## 💬 Getting Help

- **GitHub Discussions** - Best for questions and ideas
- **Issues** - For bugs and feature requests  
- **Email maintainers** - For sensitive topics

## 📜 Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you're expected to uphold this code.

## 🏆 Hall of Fame

Special thanks to these amazing contributors:

- **Harry.Tran** (@hoangtaiki) - Project creator and maintainer
- **[Your name here!]** - We'd love to add you!

---

**Remember**: No contribution is too small! Even fixing a typo helps make Appom better for everyone. 🌟

Happy coding! 🚀