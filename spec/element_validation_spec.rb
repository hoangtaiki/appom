# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Appom::ElementValidation do
  describe '.validate_element_args' do
    it 'validates valid element arguments' do
      expect do
        described_class.validate_element_args(:button, :id, 'submit')
      end.not_to raise_error
    end

    it 'validates element name and find arguments' do
      expect(described_class).to receive(:validate_element_name).with(:button)
      expect(described_class).to receive(:validate_find_arguments).with([:id, 'submit'])

      described_class.validate_element_args(:button, :id, 'submit')
    end
  end

  describe '.validate_section_args' do
    let(:section_class) { Class.new(Appom::Section) }

    it 'validates section arguments with class' do
      expect do
        described_class.validate_section_args(:header, section_class, :class, 'header')
      end.not_to raise_error
    end

    it 'validates section arguments without class' do
      expect do
        described_class.validate_section_args(:header, :class, 'header')
      end.not_to raise_error
    end

    it 'validates section class when provided' do
      expect(described_class).to receive(:validate_section_class).with(section_class)

      described_class.validate_section_args(:header, section_class, :class, 'header')
    end
  end

  describe 'private methods' do
    describe '.validate_element_name' do
      it 'accepts valid symbol names' do
        expect do
          described_class.send(:validate_element_name, :valid_name)
        end.not_to raise_error
      end

      it 'rejects non-symbol names' do
        expect do
          described_class.send(:validate_element_name, 'string_name')
        end.to raise_error(Appom::ConfigurationError, /Element name must be a symbol/)
      end

      it 'rejects empty symbol names' do
        expect do
          described_class.send(:validate_element_name, :'')
        end.to raise_error(Appom::ConfigurationError, /Element name cannot be empty/)
      end

      it 'rejects reserved method names' do
        %i[page parent root_element initialize].each do |reserved|
          expect do
            described_class.send(:validate_element_name, reserved)
          end.to raise_error(Appom::ConfigurationError, /conflicts with reserved method/)
        end
      end
    end

    describe '.validate_find_arguments' do
      context 'with valid arguments' do
        it 'accepts valid locator strategy and value' do
          expect do
            described_class.send(:validate_find_arguments, [:id, 'submit'])
          end.not_to raise_error
        end

        it 'accepts hash as locator value' do
          expect do
            described_class.send(:validate_find_arguments, [:xpath, { 'xpath' => '//button' }])
          end.not_to raise_error
        end

        it 'accepts element options hash' do
          expect do
            described_class.send(:validate_find_arguments, [:id, 'submit', { text: 'Submit' }])
          end.not_to raise_error
        end

        it 'accepts empty arguments' do
          expect do
            described_class.send(:validate_find_arguments, [])
          end.not_to raise_error
        end
      end

      context 'with invalid locator strategies' do
        it 'rejects non-symbol locator strategies' do
          expect do
            described_class.send(:validate_find_arguments, %w[id submit])
          end.to raise_error(Appom::ConfigurationError, /First argument must be a symbol/)
        end

        it 'rejects invalid locator strategies' do
          expect do
            described_class.send(:validate_find_arguments, [:invalid_strategy, 'value'])
          end.to raise_error(Appom::ConfigurationError, /Invalid locator strategy/)
        end
      end

      context 'with invalid locator values' do
        it 'rejects non-string non-hash locator values' do
          expect do
            described_class.send(:validate_find_arguments, [:id, 123])
          end.to raise_error(Appom::ConfigurationError, /Locator value must be a string or hash/)
        end

        it 'rejects empty string locator values' do
          expect do
            described_class.send(:validate_find_arguments, [:id, ''])
          end.to raise_error(Appom::ConfigurationError, /Locator value cannot be empty/)
        end

        it 'rejects missing locator value' do
          expect do
            described_class.send(:validate_find_arguments, [:id])
          end.to raise_error(Appom::ConfigurationError, /Missing locator value/)
        end
      end

      context 'with valid locator strategies' do
        Appom::ElementValidation::VALID_LOCATOR_STRATEGIES.each do |strategy|
          it "accepts #{strategy} strategy" do
            expect do
              described_class.send(:validate_find_arguments, [strategy, 'value'])
            end.not_to raise_error
          end
        end
      end
    end

    describe '.validate_element_options' do
      context 'with valid options' do
        it 'accepts text option with string value' do
          expect do
            described_class.send(:validate_element_options, { text: 'Submit' })
          end.not_to raise_error
        end

        it 'accepts visible option with boolean value' do
          expect do
            described_class.send(:validate_element_options, { visible: true })
          end.not_to raise_error
        end

        it 'accepts enabled option with boolean value' do
          expect do
            described_class.send(:validate_element_options, { enabled: false })
          end.not_to raise_error
        end

        it 'accepts timeout option with numeric value' do
          expect do
            described_class.send(:validate_element_options, { timeout: 30 })
          end.not_to raise_error
        end

        it 'accepts multiple valid options' do
          options = { text: 'Submit', visible: true, timeout: 10 }
          expect do
            described_class.send(:validate_element_options, options)
          end.not_to raise_error
        end
      end

      context 'with invalid options' do
        it 'rejects invalid option keys' do
          expect do
            described_class.send(:validate_element_options, { invalid_key: 'value' })
          end.to raise_error(Appom::ConfigurationError, /Invalid option/)
        end

        it 'rejects non-string text values' do
          expect do
            described_class.send(:validate_element_options, { text: 123 })
          end.to raise_error(Appom::ConfigurationError, /Text option must be a string/)
        end

        it 'rejects non-boolean visible values' do
          expect do
            described_class.send(:validate_element_options, { visible: 'true' })
          end.to raise_error(Appom::ConfigurationError, /Visible option must be true or false/)
        end

        it 'rejects non-boolean enabled values' do
          expect do
            described_class.send(:validate_element_options, { enabled: 1 })
          end.to raise_error(Appom::ConfigurationError, /Enabled option must be true or false/)
        end

        it 'rejects non-numeric timeout values' do
          expect do
            described_class.send(:validate_element_options, { timeout: 'thirty' })
          end.to raise_error(Appom::ConfigurationError, /Timeout must be a positive number/)
        end

        it 'rejects negative timeout values' do
          expect do
            described_class.send(:validate_element_options, { timeout: -5 })
          end.to raise_error(Appom::ConfigurationError, /Timeout must be a positive number/)
        end

        it 'rejects zero timeout values' do
          expect do
            described_class.send(:validate_element_options, { timeout: 0 })
          end.to raise_error(Appom::ConfigurationError, /Timeout must be a positive number/)
        end
      end
    end

    describe '.validate_section_class' do
      let(:valid_section_class) { Class.new(Appom::Section) }
      let(:invalid_class) { Class.new }

      it 'accepts valid section classes' do
        expect do
          described_class.send(:validate_section_class, valid_section_class)
        end.not_to raise_error
      end

      it 'rejects non-class objects' do
        expect do
          described_class.send(:validate_section_class, 'not a class')
        end.to raise_error(Appom::ConfigurationError, /Section class must be a Class/)
      end

      it 'rejects classes that do not inherit from Appom::Section' do
        expect do
          described_class.send(:validate_section_class, invalid_class)
        end.to raise_error(Appom::ConfigurationError, /must inherit from Appom::Section/)
      end
    end
  end

  describe 'constant VALID_LOCATOR_STRATEGIES' do
    it 'includes all expected Appium locator strategies' do
      expected_strategies = %i[
        accessibility_id android_uiautomator android_viewtag
        android_data_matcher android_view_matcher ios_predicate
        ios_uiautomation ios_class_chain class_name class
        css id name link_text partial_link_text tag_name xpath
      ]

      expect(described_class::VALID_LOCATOR_STRATEGIES).to include(*expected_strategies)
    end

    it 'is frozen to prevent modifications' do
      expect(described_class::VALID_LOCATOR_STRATEGIES).to be_frozen
    end
  end
end
