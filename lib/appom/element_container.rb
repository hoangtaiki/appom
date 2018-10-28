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
    def merge_args(find_args, runtime_args)
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
        build_element(name, *find_args) do |*runtime_args, &block|
          define_method(name) do
            raise_if_block(self, name, !block.nil?, :element)
            find(*merge_args(find_args, runtime_args))
          end
          define_method("#{name}_params") do
            merge_args(find_args, runtime_args)
          end
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
        build_elements(name, *find_args) do |*runtime_args, &block|
          define_method(name) do
            raise_if_block(self, name, !block.nil?, :elements)
            all(*merge_args(find_args, runtime_args))
          end
          define_method("#{name}_params") do
            merge_args(find_args, runtime_args)
          end
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

      # Add item to @mapped_items or define method for element
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

      # Define method to notify that we can't find item without args
      def create_error_method(name)
        define_method(name) do
          raise Appom::InvalidElementError
        end
      end

      def add_helper_methods(name, *find_args)
        create_existence_checker(name, *find_args)
        create_nonexistence_checker(name, *find_args)
        create_get_all_elements(name, *find_args)
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
        method_name = "has_#{element_name}?"
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
        method_name = "has_no_#{element_name}?"
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
            wait_check_util_empty(*args)
          end
        end
      end

      ##
      # Try wait until element will be enable
      #
      def create_enable_checker(element_name, *find_args)
        method_name = "#{element_name}_enable?"
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
        method_name = "#{element_name}_disable?"
        create_helper_method(method_name, *find_args) do
          define_method(method_name) do |*runtime_args|
            args = merge_args(find_args, runtime_args)
            wait_util_element_disabled(*args)
          end
        end
      end
    end
  end
end
