require 'yaml'
require 'erb'
require 'json'

module Appom
  module Configuration
    # Configuration management with environment-specific settings
    class Config
      include Logging

      DEFAULT_CONFIG_FILE = 'appom.yml'.freeze
      DEFAULT_CONFIG_PATHS = [
        './config/appom.yml',
        './appom.yml',
        './test/appom.yml',
        './spec/appom.yml'
      ].freeze

      attr_reader :data, :environment, :config_file

      def initialize(config_file: nil, environment: nil)
        @config_file = config_file || find_config_file
        @environment = environment || detect_environment
        @data = {}
        load_configuration
      end

      # Get configuration value with dot notation
      def get(key_path, default = nil)
        keys = key_path.to_s.split('.')
        value = keys.reduce(@data) { |hash, key| hash&.dig(key) }
        value.nil? ? default : value
      end

      # Set configuration value with dot notation
      def set(key_path, value)
        keys = key_path.to_s.split('.')
        last_key = keys.pop
        
        target = keys.reduce(@data) do |hash, key|
          hash[key] ||= {}
        end
        
        target[last_key] = value
      end

      # Merge configuration hash
      def merge!(other_config)
        @data = deep_merge(@data, other_config)
        self
      end

      # Reload configuration from file
      def reload!
        load_configuration
        log_info("Configuration reloaded from #{@config_file}")
        self
      end

      # Validate configuration against schema
      def validate!
        schema = ConfigSchema.new
        errors = schema.validate(@data)
        
        if errors.any?
          raise ConfigurationError.new('validation', @data, "Configuration validation failed: #{errors.join(', ')}")
        end
        
        log_info("Configuration validation passed")
        true
      end

      # Save current configuration to file
      def save!(file_path = nil)
        target_file = file_path || @config_file
        
        File.write(target_file, YAML.dump(@data))
        log_info("Configuration saved to #{target_file}")
      end

      # Get all configuration as hash
      def to_h
        @data.dup
      end

      # Check if configuration key exists
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
        yaml_data = YAML.safe_load(erb_content) || {}
        
        @data = deep_merge(@data, yaml_data)
      rescue => e
        log_error("Failed to load configuration from #{file_path}", { error: e.message })
        load_defaults
      end

      def load_defaults
        @data = {
          'appium' => {
            'server_url' => 'http://localhost:4723/wd/hub',
            'timeout' => 30,
            'implicit_wait' => 5
          },
          'appom' => {
            'max_wait_time' => 30,
            'log_level' => 'info',
            'screenshot' => {
              'directory' => 'screenshots',
              'format' => 'png',
              'auto_timestamp' => true,
              'on_failure' => true
            },
            'cache' => {
              'enabled' => true,
              'max_size' => 50,
              'ttl' => 30
            },
            'retry' => {
              'max_attempts' => 3,
              'base_delay' => 0.5,
              'backoff_multiplier' => 1.5
            }
          },
          'capabilities' => {
            'platformName' => 'iOS',
            'deviceName' => 'iPhone Simulator',
            'automationName' => 'XCUITest'
          }
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
          'APP_PATH' => 'capabilities.app'
        }

        env_mappings.each do |env_var, config_path|
          if ENV[env_var]
            value = parse_env_value(ENV[env_var])
            set(config_path, value)
            log_debug("Override from ENV[#{env_var}]: #{config_path} = #{value}")
          end
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
        hash1.merge(hash2) do |key, old_val, new_val|
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
        'cache.ttl' => { type: Numeric, min: 1, max: 3600 }
      }.freeze

      def validate(config_data)
        errors = []
        
        # Check required top-level keys
        REQUIRED_KEYS.each do |key|
          unless config_data.key?(key)
            errors << "Missing required configuration section: #{key}"
          end
        end
        
        # Validate appom configuration
        if config_data['appom']
          errors.concat(validate_appom_config(config_data['appom']))
        end
        
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
        
        # Type validation
        if constraints[:type]
          valid_types = Array(constraints[:type])
          unless valid_types.any? { |type| value.is_a?(type) }
            errors << "#{key_path} must be of type #{valid_types.join(' or ')}, got #{value.class}"
          end
        end
        
        # Value constraints
        if constraints[:values] && !constraints[:values].include?(value)
          errors << "#{key_path} must be one of #{constraints[:values].join(', ')}, got #{value}"
        end
        
        if constraints[:min] && value.respond_to?(:<) && value < constraints[:min]
          errors << "#{key_path} must be at least #{constraints[:min]}, got #{value}"
        end
        
        if constraints[:max] && value.respond_to?(:>) && value > constraints[:max]
          errors << "#{key_path} must be at most #{constraints[:max]}, got #{value}"
        end
        
        errors
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
      def configure(config_data = nil, &block)
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
      def load_from_file(file_path, environment: nil)
        @config = Config.new(config_file: file_path, environment: environment)
        apply_to_appom
        @config
      end

      # Apply configuration values to Appom modules
      def apply_to_appom
        # Set global wait time
        Appom.max_wait_time = config.get('appom.max_wait_time', 30)
        
        # Configure logging
        log_level = config.get('appom.log_level', 'info').to_sym
        Appom.configure_logging(level: log_level)
        
        # Configure caching
        cache_config = {
          enabled: config.get('appom.cache.enabled', true),
          max_size: config.get('appom.cache.max_size', 50),
          ttl: config.get('appom.cache.ttl', 30)
        }
        Appom.configure_cache(**cache_config)
        
        # Configure screenshots
        screenshot_config = {
          directory: config.get('appom.screenshot.directory', 'screenshots'),
          format: config.get('appom.screenshot.format', 'png').to_sym,
          auto_timestamp: config.get('appom.screenshot.auto_timestamp', true)
        }
        Screenshot.configure(**screenshot_config)
        
        # No logging here to avoid method missing errors
      end

      # Module-level convenience methods
      def get(key_path, default = nil)
        config.get(key_path, default)
      end

      def set(key_path, value)
        config.set(key_path, value)
      end
    end
  end
end