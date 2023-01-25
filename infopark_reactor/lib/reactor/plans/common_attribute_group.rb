module Reactor
  module Plans
    class CommonAttributeGroup
      include Prepared

      ALLOWED_PARAMS = %i(title index).freeze

      def initialize
        @params = {}
      end

      def set(key, value)
        key = key.to_sym
        if key == :attributes
          @attributes = value
        else
          @params[key.to_sym] = value
        end
      end

      def add_attributes(attributes)
        @add_attributes = attributes
      end

      def remove_attributes(attributes)
        @remove_attributes = attributes
      end

      def migrate!
        raise "#{self.class.name} did not implement migrate!"
      end

      protected

      def prepare_params!(_attribute = nil)
        @params.keys.each { |k| error("unknown parameter: #{k}") unless ALLOWED_PARAMS.include? k }
      end

      def migrate_params!(attribute)
        attribute.add_attributes(@add_attributes) if @add_attributes
        attribute.remove_attributes(@remove_attributes) if @remove_attributes
        if @attributes
          previous_attributes = attribute.attributes
          attribute.remove_attributes(previous_attributes)
          attribute.add_attributes(@attributes)
        end
        @params.each { |k, v| attribute.set(k, v) }
        attribute.save!
      end
    end
  end
end
