# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Appom::Configuration do
  let(:temp_config_file) { 'tmp_test_config.yml' }
  let(:sample_config) do
    {
      'appium' => {
        'server_url' => 'http://localhost:4723/wd/hub',
        'timeout' => 30,
      },
      'appom' => {
        'max_wait_time' => 25,
        'log_level' => 'debug',
      },
    }
  end

  after do
    FileUtils.rm_f(temp_config_file)
    described_class.instance_variable_set(:@config, nil)
  rescue Errno::ENOENT
    # Ignore if file doesn't exist
  end

  describe '.config' do
    it 'returns a Config instance' do
      expect(described_class.config).to be_a(Appom::Configuration::Config)
    end

    it 'memoizes the config instance' do
      config1 = described_class.config
      config2 = described_class.config
      expect(config1).to be(config2)
    end
  end

  describe '.configure' do
    it 'yields the config instance when block given' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class.config)
    end

    it 'merges hash data when provided' do
      described_class.configure('test' => { 'value' => 123 })
      expect(described_class.config.get('test.value')).to eq(123)
    end

    it 'applies configuration to Appom after configuration' do
      expect(described_class).to receive(:apply_to_appom)
      described_class.configure { |c| c.set('test', true) }
    end
  end

  describe '.load_from_file' do
    before do
      File.write(temp_config_file, YAML.dump(sample_config))
    end

    it 'loads configuration from specified file' do
      config = described_class.load_from_file(temp_config_file)
      expect(config.get('appom.max_wait_time')).to eq(25)
    end

    it 'applies configuration to Appom after loading' do
      expect(described_class).to receive(:apply_to_appom)
      described_class.load_from_file(temp_config_file)
    end

    it 'uses specified environment' do
      config = described_class.load_from_file(temp_config_file, environment: 'test')
      expect(config.environment).to eq('test')
    end
  end

  describe '.apply_to_appom' do
    before do
      allow(Appom).to receive(:max_wait_time=)
      allow(Appom).to receive(:configure_logging)
      allow(Appom).to receive(:configure_cache)
      allow(Appom::Screenshot).to receive(:configure)
    end

    it 'sets global wait time' do
      described_class.config.set('appom.max_wait_time', 35)
      expect(Appom).to receive(:max_wait_time=).with(35)

      described_class.apply_to_appom
    end

    it 'configures logging with specified level' do
      described_class.config.set('appom.log_level', 'error')
      expect(Appom).to receive(:configure_logging).with(level: :error)

      described_class.apply_to_appom
    end

    it 'configures caching with specified options' do
      described_class.config.set('appom.cache.enabled', false)
      described_class.config.set('appom.cache.max_size', 100)
      described_class.config.set('appom.cache.ttl', 60)

      expect(Appom).to receive(:configure_cache).with(
        enabled: false,
        max_size: 100,
        ttl: 60,
      )

      described_class.apply_to_appom
    end

    it 'configures screenshots with specified options' do
      described_class.config.set('appom.screenshot.directory', 'custom_screenshots')
      described_class.config.set('appom.screenshot.format', 'jpg')
      described_class.config.set('appom.screenshot.auto_timestamp', false)

      expect(Appom::Screenshot).to receive(:configure).with(
        directory: 'custom_screenshots',
        format: :jpg,
        auto_timestamp: false,
      )

      described_class.apply_to_appom
    end
  end

  describe '.get and .set' do
    it 'delegates get to config instance' do
      described_class.config.set('test.key', 'value')
      expect(described_class.get('test.key')).to eq('value')
    end

    it 'delegates set to config instance' do
      described_class.set('test.key', 'new_value')
      expect(described_class.config.get('test.key')).to eq('new_value')
    end
  end

  describe Appom::Configuration::Config do
    let(:config) { described_class.new }

    describe '#initialize' do
      it 'accepts config_file and environment parameters' do
        config = described_class.new(config_file: 'test.yml', environment: 'test')
        expect(config.config_file).to eq('test.yml')
        expect(config.environment).to eq('test')
      end

      it 'auto-detects config file if not provided' do
        allow(File).to receive(:exist?).and_return(false, true)
        config = described_class.new
        expect(config.config_file).to eq('./appom.yml')
      end

      it 'auto-detects environment from ENV if not provided' do
        ENV['APPOM_ENV'] = 'staging'
        config = described_class.new
        expect(config.environment).to eq('staging')
        ENV.delete('APPOM_ENV')
      end
    end

    describe '#get' do
      before { config.instance_variable_set(:@data, { 'key1' => { 'key2' => 'value' } }) }

      it 'retrieves nested values using dot notation' do
        expect(config.get('key1.key2')).to eq('value')
      end

      it 'returns default value for missing keys' do
        expect(config.get('missing.key', 'default')).to eq('default')
      end

      it 'returns nil for missing keys without default' do
        expect(config.get('missing.key')).to be_nil
      end
    end

    describe '#set' do
      it 'sets nested values using dot notation' do
        config.set('nested.key', 'value')
        expect(config.get('nested.key')).to eq('value')
      end

      it 'creates intermediate hashes as needed' do
        config.set('deep.nested.key', 'value')
        expect(config.data['deep']['nested']['key']).to eq('value')
      end
    end

    describe '#merge!' do
      it 'deep merges configuration hash' do
        config.set('key1.subkey1', 'original')
        config.merge!('key1' => { 'subkey2' => 'new' }, 'key2' => 'value')

        expect(config.get('key1.subkey1')).to eq('original')
        expect(config.get('key1.subkey2')).to eq('new')
        expect(config.get('key2')).to eq('value')
      end

      it 'returns self for chaining' do
        result = config.merge!('key' => 'value')
        expect(result).to be(config)
      end
    end

    describe '#reload!' do
      before do
        File.write(temp_config_file, YAML.dump(sample_config))
        config.instance_variable_set(:@config_file, temp_config_file)
      end

      it 'reloads configuration from file' do
        config.set('test', 'old_value')
        config.reload!
        expect(config.get('appom.max_wait_time')).to eq(25)
        expect(config.get('test')).to be_nil
      end

      it 'logs reload message' do
        expect(config).to receive(:log_info).with("Configuration reloaded from #{temp_config_file}")
        config.reload!
      end

      it 'returns self' do
        expect(config.reload!).to be(config)
      end
    end

    describe '#validate!' do
      let(:schema) { instance_double(Appom::Configuration::ConfigSchema) }

      before do
        allow(Appom::Configuration::ConfigSchema).to receive(:new).and_return(schema)
      end

      it 'validates configuration using schema' do
        allow(schema).to receive(:validate).and_return([])
        expect(schema).to receive(:validate).with(config.data)

        config.validate!
      end

      it 'raises ConfigurationError on validation failures' do
        allow(schema).to receive(:validate).and_return(['Error 1', 'Error 2'])

        expect do
          config.validate!
        end.to raise_error(Appom::ConfigurationError)

        begin
          config.validate!
        rescue Appom::ConfigurationError => e
          expect(e.message).to include('Error 1, Error 2')
        end
      end

      it 'logs success message on valid configuration' do
        allow(schema).to receive(:validate).and_return([])
        expect(config).to receive(:log_info).with('Configuration validation passed')

        config.validate!
      end

      it 'returns true on successful validation' do
        allow(schema).to receive(:validate).and_return([])
        expect(config.validate!).to be(true)
      end
    end

    describe '#save!' do
      it 'saves configuration to specified file' do
        config.set('test', 'value')
        config.save!(temp_config_file)

        loaded_data = YAML.safe_load_file(temp_config_file, aliases: true)
        expect(loaded_data['test']).to eq('value')
      end

      it 'saves to original config file if no path specified' do
        config.instance_variable_set(:@config_file, temp_config_file)
        config.set('test', 'value')
        config.save!

        expect(File.exist?(temp_config_file)).to be(true)
      end

      it 'logs save message' do
        expect(config).to receive(:log_info).with("Configuration saved to #{temp_config_file}")
        config.save!(temp_config_file)
      end
    end

    describe '#to_h' do
      it 'returns copy of configuration data' do
        config.set('key', 'value')
        hash = config.to_h

        expect(hash['key']).to eq('value')
        expect(hash).not_to be(config.data)
      end
    end

    describe '#key?' do
      before { config.set('existing.key', 'value') }

      it 'returns true for existing keys' do
        expect(config.key?('existing.key')).to be(true)
      end

      it 'returns false for missing keys' do
        expect(config.key?('missing.key')).to be(false)
      end
    end

    describe 'private methods' do
      describe '#load_from_environment' do
        before do
          ENV['APPIUM_SERVER_URL'] = 'http://custom:4723'
          ENV['APPOM_MAX_WAIT_TIME'] = '40'
          ENV['APPOM_CACHE_ENABLED'] = 'false'
        end

        after do
          ENV.delete('APPIUM_SERVER_URL')
          ENV.delete('APPOM_MAX_WAIT_TIME')
          ENV.delete('APPOM_CACHE_ENABLED')
        end

        it 'loads configuration from environment variables' do
          config.send(:load_from_environment)

          expect(config.get('appium.server_url')).to eq('http://custom:4723')
          expect(config.get('appom.max_wait_time')).to eq(40)
          expect(config.get('appom.cache.enabled')).to be(false)
        end
      end

      describe '#parse_env_value' do
        it 'parses boolean strings' do
          expect(config.send(:parse_env_value, 'true')).to be(true)
          expect(config.send(:parse_env_value, 'false')).to be(false)
        end

        it 'parses integer strings' do
          expect(config.send(:parse_env_value, '42')).to eq(42)
        end

        it 'parses float strings' do
          expect(config.send(:parse_env_value, '3.14')).to eq(3.14)
        end

        it 'parses JSON strings' do
          expect(config.send(:parse_env_value, '{"key":"value"}')).to eq({ 'key' => 'value' })
        end

        it 'returns string for unparseable values' do
          expect(config.send(:parse_env_value, 'plain_string')).to eq('plain_string')
        end
      end
    end
  end

  describe Appom::Configuration::ConfigSchema do
    let(:schema) { described_class.new }

    describe '#validate' do
      it 'validates required top-level keys' do
        config_data = { 'appium' => {} }
        errors = schema.validate(config_data)

        expect(errors).to include('Missing required configuration section: appom')
      end

      it 'validates appom configuration values' do
        config_data = {
          'appom' => { 'max_wait_time' => -5 },
          'appium' => {},
        }
        errors = schema.validate(config_data)

        expect(errors).to include(match(/max_wait_time must be at least 1/))
      end

      it 'returns empty array for valid configuration' do
        config_data = {
          'appom' => {
            'max_wait_time' => 30,
            'log_level' => 'info',
          },
          'appium' => {},
        }
        errors = schema.validate(config_data)

        expect(errors).to be_empty
      end
    end
  end
end
