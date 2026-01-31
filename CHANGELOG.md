# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-01-31

### 🚀 Added
- **Complete Exception Hierarchy**: Comprehensive error types with context and detailed messages
  - `ElementNotFoundError`, `ElementStateError`, `WaitError`, `DriverError`, etc.
  - All exceptions include context information and detailed error messages
- **Structured Logging System**: Configurable logging with multiple output formats
  - Debug, info, warn, error levels with timing information
  - Element interaction logging and performance tracking
- **Element Validation**: Comprehensive validation for element definitions
  - Validates locator strategies, element names, and parameters
  - Prevents common configuration errors at definition time
- **Helper Methods**: Rich set of helper methods for common patterns
  - `tap_and_wait`, `scroll_to_and_tap`, `get_text_with_retry`
  - `wait_for_any`, `wait_for_disappear`, `wait_for_text_in_element`
  - Debug helpers: `take_debug_screenshot`, `dump_page_source`, `debug_elements_info`
- **Retry Mechanisms**: Intelligent retry logic with exponential backoff
  - Configurable retry attempts, delays, and conditions
  - Element-specific retry methods: `find_with_retry`, `interact_with_retry`
- **Enhanced Testing**: Complete RSpec test suite with coverage reporting
- **CI/CD Pipeline**: GitHub Actions with multi-Ruby version testing
- **YARD Documentation**: Comprehensive API documentation

### 🔄 Changed  
- **BREAKING**: Minimum Ruby version raised to 2.7.0
- **BREAKING**: Updated dependencies:
  - `appium_lib` ~> 15.0 (was >= 9.4)
  - `cucumber` ~> 9.0 (was >= 2.3)
- **BREAKING**: Exception names changed:
  - `Appom::InvalidElementError` -> `InvalidElementError` (module-scoped)
  - `Appom::UnsupportedBlockError` -> `UnsupportedBlockError` (module-scoped)
- **Improved**: Exit handler now includes proper error handling
- **Enhanced**: Wait class now includes logging and better error propagation

### 🛡️ Security
- Updated all dependencies to latest secure versions
- Added bundler-audit to CI pipeline

### 📚 Documentation
- Complete README rewrite with comprehensive examples
- Added inline YARD documentation for public APIs  
- Added contributing guidelines and code of conduct
- Created improvement checklist and progress tracking

### 🧪 Testing
- Added RSpec test framework with SimpleCov coverage
- Created test fixtures and mocks for Appium driver
- Added tests for core classes: Appom, Wait, Page, ElementContainer
- Configured continuous integration with GitHub Actions

---

## [1.4.0] - 2018-11-10 (Previous Release)
### Added
- Add `#section` support for nested UI components

## [0.8.0] - 2018-10-11  
### Added
- Add `#element_verify_text` function to get element text and compare
### Changed
- Create a function to define `#element_params`

## [0.7.0] - 2018-10-29
### Added
- Add `#section` basic implementation

## [0.6.0] - 2018-10-28
### Added
- Add `#element_params` function to get parameters when define element
- Add `#element_enable` function to wait until element will be enabled  
- Add `#element_disable` function to wait until element will be disabled

