require './lib/appom/version'

Gem::Specification.new do |spec|
  spec.name          = 'appom'
  spec.version       = Appom::VERSION
  spec.authors       = ['Harry.Tran']
  spec.email         = ['duchoang.vp@gmail.com']

  spec.summary       = 'A comprehensive Page Object Model framework for Appium with advanced testing capabilities'
  spec.description   = 'Appom provides a clean, semantic DSL for mobile application testing. Built on Appium, it includes performance monitoring, visual regression testing, element state tracking, smart waiting, and intelligent caching for enterprise-grade test automation.'
  spec.homepage      = 'https://github.com/hoangtaiki/appom'
  spec.license       = 'MIT'

  spec.files         = Dir.glob('lib/**/*') + %w[LICENSE.txt README.md]

  spec.required_ruby_version = '>= 3.2.2'
  spec.bindir        = 'exe'
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'appium_lib', '>= 16.0'
  spec.add_dependency 'cucumber', '~> 9.0'
  spec.add_dependency 'selenium-webdriver', '>= 4.0'

  # Development dependencies are now specified in the Gemfile.
  spec.metadata['rubygems_mfa_required'] = 'true'
end
