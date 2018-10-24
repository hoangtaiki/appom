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
      # @param *find_args       An array contain information to find the element. It contains locator stratery and search target
      # http://appium.io/docs/en/commands/element/find-element/
      #
      # Element doesn't support block so that will raise if pass a block when declare
      #
      def element(name, *find_args)
        build(name, *find_args) do |*runtime_args, &block|
          define_method(name) do
            raise_if_block(self, name, !block.nil?, :element)
            find(*merge_args(find_args, runtime_args))
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
      # @param *find_args       An array contain information to find the elements. It contains locator stratery and search target
      # http://appium.io/docs/en/commands/element/find-element/
      #
      # Elements doesn't support block so that will raise if pass a block when declare
      #
      def elements(name, *find_args)
        build(name, *find_args) do |*runtime_args, &block|
          define_method(name) do
            raise_if_block(self, name, !block.nil?, :elements)
            all(*merge_args(find_args, runtime_args))
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

      # Add item to @mapped_items or define mothod to notify that we can't find item without args
      def build(name, *find_args)
        if find_args.empty?
          create_error_method(name)
        else
          add_to_mapped_items(name)
          yield
        end
      end

      # Define mothod to notify that we can't find item without args
      def create_error_method(name)
        define_method(name) do
          raise Appom::InvalidElementError
        end
      end
    end
  end
end
