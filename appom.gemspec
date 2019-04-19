require './lib/appom/version'

Gem::Specification.new do |spec|
  spec.name          = 'appom'
  spec.version       = Appom::VERSION
  spec.authors       = ['Harry.Tran']
  spec.email         = ['hoang@platphormcorp.com']

  spec.summary       = 'A Page Object Model for Appium'
  spec.description   = 'Appom gives you a simple, clean and semantic for describing your application. Appom implements the Page Object Model pattern on top of Appium.'
  spec.homepage      = 'https://github.com/hoangtaiki/appom'
  spec.license       = 'MIT'

  spec.files         = Dir.glob('lib/**/*') + %w[LICENSE.txt README.md]

  spec.required_ruby_version = '>= 2.2.3'
  spec.bindir        = 'exe'
  spec.require_paths = ['lib']
  spec.add_dependency 'appium_lib', '>= 9.4'
  spec.add_dependency 'cucumber', '>= 2.3'
  spec.add_development_dependency 'rubocop', '>= 0.58'
end
