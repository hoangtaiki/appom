# Appom
[![Gem Version](https://badge.fury.io/rb/appom.svg)](http://badge.fury.io/rb/appom)

A Page Object Model for Appium

Appom gives you a simple, clean and semantic for describing your application. Appom implements the Page Object Model pattern on top of Appium.

## Idea
If you have used the [Page Object Model](https://medium.com/tech-tajawal/page-object-model-pom-design-pattern-f9588630800b) (POM) with Appium you will probably know about [Capybara](https://github.com/teamcapybara/capybara) and [SitePrism](https://github.com/natritmeyer/site_prism). But CapyBara and SitePrism are designed for the web rather than the mobile.

Using POM with SitePrism and CapyBara makes interacting with Appium really not that direct. And Appium is not confirmed to work well with these two libraries.

Wishing to use the Page Object Model in the simplest way we created Appom. The idea created for Appom is taken from CapyBara and SitePrism.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'appom'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install appom

## Usage

Here's an overview of how Appom is designed to be used:

### Register Appium Driver
Appium use appium directly to find elements. So that to use Appom you must register Appium Driver for Appom
```ruby
Appom.register_driver do
  options = {
    appium_lib: appium_lib_options,
    caps: caps
  }
  Appium::Driver.new(options, false)
end
```
`appium_lib_options` and `caps` are options to initiate a appium driver. You can follow [Appium Ruby Client](https://github.com/appium/ruby_lib)


### Define a page
```ruby
class LoginPage < Appom::Page
  element :email, :accessibility_id, 'email_text_field'
  element :password, :accessibility_id, 'password_text_field'
  element :sign_in_button, :accessibility_id, 'sign_in_button'
end
```

## Example
[authentication-appom-appium](https://github.com/hoangtaiki/authentication-appom-appium) is an example about using Appom with Appium. 


## Contributing

Bug reports and pull requests are welcome on GitHub at [Appom](https://github.com/hoangtaiki/appom). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Appom project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/hoangtaiki/appom/blob/master/CODE_OF_CONDUCT.md).
