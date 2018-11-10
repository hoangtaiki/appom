module Appom
  module ElementContainer
    def self.included(klass)
      klass.extend ClassMethods
    end

    # Raise if contain a block
    def raise_if_block(obj, name, has_block, type)
      return unless has_block

      puts "Type passed in: #{type}"
      puts "#{obj.class}##{name} does not accept blocks"

      raise Appom::UnsupportedBlockError
    end

    ##
    # Options re-combiner. This takes the original inputs and combines
    # them such that there is only one hash passed as a final argument
    # to Appium.
    #
    def merge_args(find_args, runtime_args={})
      find_args = find_args.dup.flatten
      runtime_args = runtime_args.dup

      [*find_args, *runtime_args]
    end

    module ClassMethods
      attr_reader :mapped_items

      ##
      #
      # Declare an element with name and args to find it
      #
      #     element :email, :accessibility_id, 'email_text_field'
      #
      # @param name             Element name
      # @param *find_args       An array contain information to find the element. It contains locator strategy and search target
      # http://appium.io/docs/en/commands/element/find-element/
      #
      # Element doesn't support block so that will raise if pass a block when declare
      #
      def element(name, *find_args)
        text, args = deduce_element_text(find_args)
        build_element(name, *args) do
          define_method(name) do |*runtime_args, &block|
            raise_if_block(self, name, !block.nil?, :element)
            _find(*merge_args(args, runtime_args))
          end

          create_get_element_params(name, args)
          create_verify_element_text(name, text, args)
        end
      end

      ##
      #
      # Declare an elements with name and args to find it
      #
      #     elements :contact_cell, :accessibility_id, 'contact_cell'
      #
      # @param name             Element name
      # @param *find_args       An array contain information to find the elements. It contains locator strategy and search target
      # http://appium.io/docs/en/commands/element/find-element/
      #
      # Elements doesn't support block so that will raise if pass a block when declare
      #
      def elements(name, *find_args)
        build_elements(name, *find_args) do
          define_method(name) do |*runtime_args, &block|
            raise_if_block(self, name, !block.nil?, :elements)
            _all(*merge_args(find_args, runtime_args))
          end

          create_get_element_params(name, find_args)
        end
      end

      def section(name, *args, &block)
        section_class, find_args = extract_section_options(args, &block)
        build_element(name, *find_args) do
          define_method(name) do |*runtime_args, &block|
            section_element = _find(*merge_args(find_args, runtime_args))
            section_class.new(self, section_element)
          end

          create_get_element_params(name, find_args)
        end


      end

      def sections(name, *args, &block)
        section_class, find_args = extract_section_options(args, &block)
        build_sections(section_class, name, *find_args) do
          define_method(name) do |*runtime_args, &block|
            raise_if_block(self, name, !block.nil?, :sections)
            _all(*merge_args(find_args, runtime_args)).map do |element|
              section_class.new(self, element)
            end
          end

          create_get_element_params(name, find_args)
        end
      end

      ##
      # Add item to @mapped_items array
      #
      # @param item         Item need to add
      #
      def add_to_mapped_items(item)
        @mapped_items ||= []
        @mapped_items << item
      end

      private

      # Add item to @mapped_items or define method for element and section
      def build_element(name, *find_args)
        if find_args.empty?
          create_error_method(name)
        else
          add_to_mapped_items(name)
          yield
        end

        create_existence_checker(name, *find_args)
        create_nonexistence_checker(name, *find_args)
        create_enable_checker(name, *find_args)
        create_disable_checker(name, *find_args)
      end

      # Add item to @mapped_items or define method for elements
      def build_elements(name, *find_args)
        if find_args.empty?
          create_error_method(name)
        else
          add_to_mapped_items(name)
          yield
        end

        create_existence_checker(name, *find_args)
        create_nonexistence_checker(name, *find_args)
        create_get_all_elements(name, *find_args)
      end

      # Add item to @mapped_items or define method for elements
      def build_sections(section_class, name, *find_args)
        if find_args.empty?
          create_error_method(name)
        else
          add_to_mapped_items(name)
          yield
        end

        create_existence_checker(name, *find_args)
        create_nonexistence_checker(name, *find_args)
        create_get_all_sections(section_class, name, *find_args)
      end

      # Define method to notify that we can't find item without args
      def create_error_method(name)
        define_method(name) do
          raise Appom::InvalidElementError
        end
      end

      def create_helper_method(proposed_method_name, *find_args)
        if find_args.empty?
          create_error_method(proposed_method_name)
        else
          yield
        end
      end

      ##
      # Check element exist
      # We will try to find all elements with *find_args
      # Condition is pass when response is not empty
      #
      def create_existence_checker(element_name, *find_args)
        method_name = "wait_until_has_#{element_name}"
        create_helper_method(method_name, *find_args) do
          define_method(method_name) do |*runtime_args|
            args = merge_args(find_args, runtime_args)
            wait_check_util_not_empty(*args)
          end
        end
      end

      ##
      # Check element non-existent
      # We will try to find all elements with *find_args
      # Condition is pass when response is empty
      #
      def create_nonexistence_checker(element_name, *find_args)
        method_name = "wait_until_has_no_#{element_name}"
        create_helper_method(method_name, *find_args) do
          define_method(method_name) do |*runtime_args|
            args = merge_args(find_args, runtime_args)
            wait_check_util_empty(*args)
          end
        end
      end

      ##
      # Try to get all elements until not get empty array
      #
      def create_get_all_elements(element_name, *find_args)
        method_name = "get_all_#{element_name}"
        create_helper_method(method_name, *find_args) do
          define_method(method_name) do |*runtime_args|
            args = merge_args(find_args, runtime_args)
            wait_util_get_not_empty(*args)
          end
        end
      end

      ##
      # Try to get all sections until not get empty array
      #
      def create_get_all_sections(section_class, element_name, *find_args)
        method_name = "get_all_#{element_name}"
        create_helper_method(method_name, *find_args) do
          define_method(method_name) do |*runtime_args|
            args = merge_args(find_args, runtime_args)
            wait_util_get_not_empty(*args).map do |element|
              section_class.new(self, element)
            end
          end
        end
      end

      ##
      # Try wait until element will be enable
      #
      def create_enable_checker(element_name, *find_args)
        method_name = "wait_until_#{element_name}_enable"
        create_helper_method(method_name, *find_args) do
          define_method(method_name) do |*runtime_args|
            args = merge_args(find_args, runtime_args)
            wait_util_element_enabled(*args)
          end
        end
      end

      ##
      # Wait until an element will be
      #
      def create_disable_checker(element_name, *find_args)
        method_name = "wait_until_#{element_name}_disable"
        create_helper_method(method_name, *find_args) do
          define_method(method_name) do |*runtime_args|
            args = merge_args(find_args, runtime_args)
            wait_util_element_disabled(*args)
          end
        end
      end

      ##
      # Verify text for an element
      #
      def create_verify_element_text(element_name, text, *find_args)
        method_name = "#{element_name}_verify_text"

        create_helper_method(method_name, *find_args) do
          define_method(method_name) do |*runtime_args|
            # Raise if element have no text value
            if text.nil?
              raise(ElementsDefineNoTextError, "#{name} element is define with no text value")
            end

            args = merge_args(find_args, runtime_args)
            element = _find(*args)
            element_text = element.text
            if !element_text.eql?(text)
              raise(ElementsTextVerifyError, "expected: value == #{text} got: #{element_text}")
            end
          end
        end
      end

      ##
      # Get parameter is passed when declared element
      #
      def create_get_element_params(element_name, *find_args)
        method_name = "#{element_name}_params"
        create_helper_method(method_name, *find_args) do
          define_method(method_name) do
            merge_args(find_args)
          end
        end
      end

      ##
      # Deduce text value
      # @return expected text for element and the remaining parameters
      #
      def deduce_element_text(args)
        # Flatten argument array first if we are in case array inside array
        args = args.flatten

        if args.empty?
          raise(ArgumentError, 'You should provide search arguments in element creation')
        end

        # Get last key and check if it contain 'text' key
        last_key = args.last
        text = nil
        if last_key.is_a?(Hash)
          if last_key.key?(:text)
            text = last_key[:text]
            args.pop
          end
        end

        [text, args]
      end

      ##
      # Extract section options
      # @return section class name and the remaining parameters
      #
      def extract_section_options(args, &block)
        if args.first.is_a?(Class)
          klass = args.shift
          section_class = klass if klass.ancestors.include?(Appom::Section)
        end

        section_class = deduce_section_class(section_class, &block)
        arguments = deduce_search_arguments(section_class, args)
        [section_class, arguments]
      end

      ##
      # Deduce section class
      #
      def deduce_section_class(base_class, &block)
        klass = base_class

        klass = Class.new(klass || Appom::Section, &block) if block_given?

        unless klass
          raise ArgumentError, 'You should provide descendant of Appom::Section class or/and a block as the second argument.'
        end
        klass
      end

      ##
      # Deduce search parameters
      #
      def deduce_search_arguments(section_class, args)
        extract_search_arguments(args) ||
          extract_search_arguments(section_class.default_search_arguments) ||
          raise(ArgumentError, 'You should provide search arguments in section creation or set_default_search_arguments within section class')
      end

      def extract_search_arguments(args)
        args if args && !args.empty?
      end

    end
  end
end
