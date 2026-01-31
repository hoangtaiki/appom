# frozen_string_literal: true

require 'yaml'
require 'erb'
require 'json'

module Appom::Configuration
  # Configuration management with environment-specific settings
  class Config
    include Appom::Logging

    DEFAULT_CONFIG_FILE = 'appom.yml'
    DEFAULT_CONFIG_PATHS = [
      './config/appom.yml',
      './appom.yml',
      './test/appom.yml',
      './spec/appom.yml',
    ].freeze

    attr_reader :data, :environment, :config_file

    def initialize(config_file: nil, environment: nil)
      @config_file = config_file || find_config_file
      @environment = environment || detect_environment
      @data = {}
      load_configuration
    end

    # Get configuration value with dot notation
    #
    # @param key_path [String, Symbol] The configuration key path using dot notation
    # @param default [Object] Default value to return if key is not found
    # @return [Object] The configuration value or default
    #
    # @example Get a nested value
    #   config.get('appom.max_wait_time', 30)
    #   config.get('appium.server_url')
    def get(key_path, default = nil)
      keys = key_path.to_s.split('.')
      value = keys.reduce(@data) { |hash, key| hash&.dig(key) }
      value.nil? ? default : value
    end

    # Set configuration value with dot notation
    #
    # @param key_path [String, Symbol] The configuration key path using dot notation
    # @param value [Object] The value to set
    # @return [Object] The value that was set
    #
    # @example Set a nested value
    #   config.set('appom.max_wait_time', 45)
    #   config.set('custom.setting', 'value')
    def set(key_path, value)
      keys = key_path.to_s.split('.')
      last_key = keys.pop

      target = keys.reduce(@data) do |hash, key|
        hash[key] ||= {}
      end

      target[last_key] = value
    end

    # Merge configuration hash
    #
    # @param other_config [Hash] Configuration hash to merge
    # @return [Config] Self for method chaining
    #
    # @example Merge additional configuration
    #   config.merge!('appom' => { 'log_level' => 'debug' })
    def merge!(other_config)
      @data = deep_merge(@data, other_config)
      self
    end

    # Reload configuration from file
    #
    # @return [Config] Self for method chaining
    #
    # @example Reload configuration after file changes
    #   config.reload!
    def reload!
      reload_configuration
      log_info("Configuration reloaded from #{@config_file}")
      self
    end

    # Validate configuration against schema
    #
    # @return [Boolean] True if validation passes
    # @raise [ConfigurationError] If validation fails
    #
    # @example Validate current configuration
    #   config.validate!
    def validate!
      schema = ConfigSchema.new
      errors = schema.validate(@data)

      if errors.any?
        raise Appom::ConfigurationError.new('validation', @data,
                                            "Configuration validation failed: #{errors.join(', ')}",)
      end

      log_info('Configuration validation passed')
      true
    end

    # Save current configuration to file
    #
    # @param file_path [String, nil] Optional file path to save to, uses current config file if nil
    # @return [void]
    #
    # @example Save configuration
    #   config.save!
    #   config.save!('backup_config.yml')
    def save!(file_path = nil)
      target_file = file_path || @config_file

      File.write(target_file, YAML.dump(@data))
      log_info("Configuration saved to #{target_file}")
    end

    # Get all configuration as hash
    #
    # @return [Hash] Deep copy of configuration data
    #
    # @example Get configuration as hash
    #   config_hash = config.to_h
    def to_h
      @data.dup
    end

    # Check if configuration key exists
    #
    # @param key_path [String, Symbol] The configuration key path using dot notation
    # @return [Boolean] True if key exists, false otherwise
    #
    # @example Check if key exists
    #   config.key?('appom.max_wait_time') # => true
    #   config.key?('missing.key')         # => false
    def key?(key_path)
      !get(key_path).nil?
    end

    private

    def find_config_file
      DEFAULT_CONFIG_PATHS.find { |path| File.exist?(path) } || DEFAULT_CONFIG_FILE
    end

    def detect_environment
      ENV['APPOM_ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
    end

    def reload_configuration
      @data = {}

      if File.exist?(@config_file)
        load_from_file(@config_file)
      else
        log_warn("Configuration file not found: #{@config_file}, using defaults")
        load_defaults
      end

      # Override with environment variables
      load_from_environment

      # Apply environment-specific settings
      apply_environment_settings

      # Don't log the standard message here - let reload! method handle it
    end

    def load_configuration
      @data = {}

      if File.exist?(@config_file)
        load_from_file(@config_file)
      else
        log_warn("Configuration file not found: #{@config_file}, using defaults")
        load_defaults
      end

      # Override with environment variables
      load_from_environment

      # Apply environment-specific settings
      apply_environment_settings

      log_info("Configuration loaded for environment: #{@environment}")
    end

    def load_from_file(file_path)
      content = File.read(file_path)
      # Process ERB templates
      erb_content = ERB.new(content).result
      yaml_data = YAML.safe_load(erb_content, aliases: true) || {}

      @data = deep_merge(@data, yaml_data)
    rescue StandardError => e
      log_error("Failed to load configuration from #{file_path}", { error: e.message })
      load_defaults
    end

    def load_defaults
      @data = {
        'appium' => {
          'server_url' => 'http://localhost:4723/wd/hub',
          'timeout' => 30,
          'implicit_wait' => 5,
        },
        'appom' => {
          'max_wait_time' => 30,
          'log_level' => 'info',
          'screenshot' => {
            'directory' => 'screenshots',
            'format' => 'png',
            'auto_timestamp' => true,
            'on_failure' => true,
          },
          'cache' => {
            'enabled' => true,
            'max_size' => 50,
            'ttl' => 30,
          },
          'retry' => {
            'max_attempts' => 3,
            'base_delay' => 0.5,
            'backoff_multiplier' => 1.5,
          },
        },
        'capabilities' => {
          'platformName' => 'iOS',
          'deviceName' => 'iPhone Simulator',
          'automationName' => 'XCUITest',
        },
      }
    end

    def load_from_environment
      # Map environment variables to configuration paths
      env_mappings = {
        'APPIUM_SERVER_URL' => 'appium.server_url',
        'APPIUM_TIMEOUT' => 'appium.timeout',
        'APPOM_MAX_WAIT_TIME' => 'appom.max_wait_time',
        'APPOM_LOG_LEVEL' => 'appom.log_level',
        'APPOM_SCREENSHOT_DIR' => 'appom.screenshot.directory',
        'APPOM_CACHE_ENABLED' => 'appom.cache.enabled',
        'DEVICE_NAME' => 'capabilities.deviceName',
        'PLATFORM_NAME' => 'capabilities.platformName',
        'APP_PATH' => 'capabilities.app',
      }

      env_mappings.each do |env_var, config_path|
        next unless ENV[env_var]

        value = parse_env_value(ENV.fetch(env_var, nil))
        set(config_path, value)
        log_debug("Override from ENV[#{env_var}]: #{config_path} = #{value}")
      end
    end

    def apply_environment_settings
      return unless @data[@environment]

      env_config = @data[@environment]
      @data = deep_merge(@data, env_config)
      log_debug("Applied #{@environment} environment settings")
    end

    def parse_env_value(value)
      # Try to parse as JSON/YAML for complex values
      case value.downcase
      when 'true' then true
      when 'false' then false
      when /^\d+$/ then value.to_i
      when /^\d+\.\d+$/ then value.to_f
      else
        # Try parsing as JSON for arrays/hashes
        begin
          JSON.parse(value)
        rescue JSON::ParserError
          value
        end
      end
    end

    def deep_merge(hash1, hash2)
      hash1.merge(hash2) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge(old_val, new_val)
        else
          new_val
        end
      end
    end
  end

  # Configuration validation schema
  class ConfigSchema
    REQUIRED_KEYS = %w[appom appium].freeze

    APPOM_SCHEMA = {
      'max_wait_time' => { type: Numeric, min: 1, max: 300 },
      'log_level' => { type: String, values: %w[debug info warn error fatal] },
      'screenshot.directory' => { type: String },
      'screenshot.format' => { type: String, values: %w[png jpg jpeg] },
      'screenshot.auto_timestamp' => { type: [TrueClass, FalseClass] },
      'cache.enabled' => { type: [TrueClass, FalseClass] },
      'cache.max_size' => { type: Integer, min: 1, max: 1000 },
      'cache.ttl' => { type: Numeric, min: 1, max: 3600 },
    }.freeze

    def validate(config_data)
      errors = []

      # Check required top-level keys
      REQUIRED_KEYS.each do |key|
        errors << "Missing required configuration section: #{key}" unless config_data.key?(key)
      end

      # Validate appom configuration
      errors.concat(validate_appom_config(config_data['appom'])) if config_data['appom']

      errors
    end

    private

    def validate_appom_config(appom_config)
      errors = []

      APPOM_SCHEMA.each do |key_path, constraints|
        value = get_nested_value(appom_config, key_path)
        next if value.nil? && !constraints[:required]

        errors.concat(validate_value(key_path, value, constraints))
      end

      errors
    end

    def validate_value(key_path, value, constraints)
      errors = []

      errors.concat(validate_value_type(key_path, value, constraints))
      errors.concat(validate_value_constraints(key_path, value, constraints))

      errors
    end

    def validate_value_type(key_path, value, constraints)
      return [] unless constraints[:type]

      valid_types = Array(constraints[:type])
      return [] if valid_types.any? { |type| value.is_a?(type) }

      ["#{key_path} must be of type #{valid_types.join(' or ')}, got #{value.class}"]
    end

    def validate_value_constraints(key_path, value, constraints)
      errors = []

      errors.concat(validate_allowed_values(key_path, value, constraints))
      errors.concat(validate_min_value(key_path, value, constraints))
      errors.concat(validate_max_value(key_path, value, constraints))

      errors
    end

    def validate_allowed_values(key_path, value, constraints)
      return [] unless constraints[:values] && !constraints[:values].include?(value)

      ["#{key_path} must be one of #{constraints[:values].join(', ')}, got #{value}"]
    end

    def validate_min_value(key_path, value, constraints)
      return [] unless constraints[:min] && value.respond_to?(:<) && value < constraints[:min]

      ["#{key_path} must be at least #{constraints[:min]}, got #{value}"]
    end

    def validate_max_value(key_path, value, constraints)
      return [] unless constraints[:max] && value.respond_to?(:>) && value > constraints[:max]

      ["#{key_path} must be at most #{constraints[:max]}, got #{value}"]
    end

    def get_nested_value(hash, key_path)
      keys = key_path.split('.')
      keys.reduce(hash) { |h, key| h&.dig(key) }
    end
  end

  # Global configuration instance
  class << self
    attr_writer :config

    def config
      @config ||= Config.new
    end

    # Configure Appom with block or hash
    def configure(config_data = nil, &)
      if block_given?
        yield config
      elsif config_data
        config.merge!(config_data)
      end

      # Apply configuration to Appom
      apply_to_appom
      config
    end

    # Load configuration from file
    #
    # @param file_path [String] Path to configuration file
    # @param environment [String, nil] Optional environment override
    # @return [Config] The loaded configuration instance
    #
    # @example Load configuration from custom file
    #   Appom::Configuration.load_from_file('config/custom.yml')
    #   Appom::Configuration.load_from_file('config/app.yml', environment: 'staging')
    def load_from_file(file_path, environment: nil)
      @config = Config.new(config_file: file_path, environment: environment)
      apply_to_appom
      @config
    end

    # Apply configuration values to Appom modules
    def apply_to_appom
      configure_appom_wait_time
      configure_appom_logging
      configure_appom_caching
      configure_appom_screenshots
    end

    # Module-level convenience methods

    # Get configuration value using dot notation
    #
    # @param key_path [String, Symbol] The configuration key path
    # @param default [Object] Default value if key not found
    # @return [Object] The configuration value or default
    def get(key_path, default = nil)
      config.get(key_path, default)
    end

    # Set configuration value using dot notation
    #
    # @param key_path [String, Symbol] The configuration key path
    # @param value [Object] The value to set
    # @return [Object] The value that was set
    def set(key_path, value)
      config.set(key_path, value)
    end

    private

    def configure_appom_wait_time
      Appom.max_wait_time = config.get('appom.max_wait_time', 30)
    end

    def configure_appom_logging
      log_level = config.get('appom.log_level', 'info').to_sym
      Appom.configure_logging(level: log_level)
    end

    def configure_appom_caching
      cache_config = {
        enabled: config.get('appom.cache.enabled', true),
        max_size: config.get('appom.cache.max_size', 50),
        ttl: config.get('appom.cache.ttl', 30),
      }
      Appom.configure_cache(**cache_config)
    end

    def configure_appom_screenshots
      screenshot_config = {
        directory: config.get('appom.screenshot.directory', 'screenshots'),
        format: config.get('appom.screenshot.format', 'png').to_sym,
        auto_timestamp: config.get('appom.screenshot.auto_timestamp', true),
      }
      Appom::Screenshot.configure(**screenshot_config) if defined?(Appom::Screenshot)
    end
  end
end
