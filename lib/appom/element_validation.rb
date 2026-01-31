module Appom
  module ElementValidation
    # Valid Appium locator strategies
    VALID_LOCATOR_STRATEGIES = [
      :accessibility_id,
      :android_uiautomator,
      :android_viewtag,
      :android_data_matcher,
      :android_view_matcher,
      :ios_predicate,
      :ios_uiautomation,
      :ios_class_chain,
      :class_name,
      :class,  # Alias for class_name
      :css,
      :id,
      :name,
      :link_text,
      :partial_link_text,
      :tag_name,
      :xpath
    ].freeze

    class << self
      # Validate element definition arguments
      def validate_element_args(name, *find_args)
        validate_element_name(name)
        validate_find_arguments(find_args)
      end

      # Validate section definition arguments  
      def validate_section_args(name, *args)
        validate_element_name(name)
        
        # Extract section class and find args
        section_class = nil
        find_args = args.dup

        if find_args.first.is_a?(Class)
          section_class = find_args.shift
          validate_section_class(section_class)
        end

        validate_find_arguments(find_args) unless find_args.empty?
      end

      private

      def validate_element_name(name)
        unless name.is_a?(Symbol)
          raise ConfigurationError.new('element_name', name, 'Element name must be a symbol')
        end

        if name.to_s.empty?
          raise ConfigurationError.new('element_name', name, 'Element name cannot be empty')
        end

        # Check for reserved method names
        reserved_methods = [:page, :parent, :root_element, :initialize]
        if reserved_methods.include?(name)
          raise ConfigurationError.new('element_name', name, 'Element name conflicts with reserved method')
        end
      end

      def validate_find_arguments(find_args)
        return if find_args.empty? # Allow empty args for some cases

        flattened_args = find_args.flatten
        return if flattened_args.empty?

        # First argument should be a locator strategy (symbol)
        locator_strategy = flattened_args.first
        unless locator_strategy.is_a?(Symbol)
          raise ConfigurationError.new('locator_strategy', locator_strategy, 
                                     'First argument must be a symbol representing locator strategy')
        end

        unless VALID_LOCATOR_STRATEGIES.include?(locator_strategy)
          valid_strategies = VALID_LOCATOR_STRATEGIES.map(&:to_s).join(', ')
          raise ConfigurationError.new('locator_strategy', locator_strategy, 
                                     "Invalid locator strategy. Valid strategies: #{valid_strategies}")
        end

        # Second argument should be the locator value (string)
        if flattened_args.size > 1
          locator_value = flattened_args[1]
          unless locator_value.is_a?(String) || locator_value.is_a?(Hash)
            raise ConfigurationError.new('locator_value', locator_value, 
                                       'Locator value must be a string or hash')
          end

          if locator_value.is_a?(String) && locator_value.empty?
            raise ConfigurationError.new('locator_value', locator_value, 
                                       'Locator value cannot be empty')
          end
        else
          raise ConfigurationError.new('find_arguments', find_args, 
                                     'Missing locator value. Expected format: :strategy, "value"')
        end

        # Validate optional hash arguments
        flattened_args[2..-1]&.each do |arg|
          if arg.is_a?(Hash)
            validate_element_options(arg)
          end
        end
      end

      def validate_element_options(options)
        valid_options = [:text, :visible, :enabled, :timeout]
        
        options.each do |key, value|
          unless valid_options.include?(key)
            valid_keys = valid_options.map(&:to_s).join(', ')
            raise ConfigurationError.new('element_option', key, 
                                       "Invalid option. Valid options: #{valid_keys}")
          end

          case key
          when :text
            unless value.is_a?(String)
              raise ConfigurationError.new('text_option', value, 'Text option must be a string')
            end
          when :visible, :enabled
            unless [true, false].include?(value)
              raise ConfigurationError.new("#{key}_option", value, "#{key.capitalize} option must be true or false")
            end
          when :timeout
            unless value.is_a?(Numeric) && value > 0
              raise ConfigurationError.new('timeout_option', value, 'Timeout must be a positive number')
            end
          end
        end
      end

      def validate_section_class(klass)
        unless klass.is_a?(Class)
          raise ConfigurationError.new('section_class', klass, 'Section class must be a Class')
        end

        unless klass.ancestors.include?(Appom::Section)
          raise ConfigurationError.new('section_class', klass, 
                                     'Section class must inherit from Appom::Section')
        end
      end
    end
  end
end