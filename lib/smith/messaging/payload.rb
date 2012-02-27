# -*- encoding: utf-8 -*-
module Smith
  module ACL

    module ClassMethods
      def encoder_class(e)
        @@pb_classes ||= {:default => Default}

        e = e.to_sym

        if @@pb_classes.include?(e)
          @@pb_classes[e]
        else
          class_name = Extlib::Inflection.camelize(e)
          if ACL.constants.include?(class_name)
            logger.error("Shouldn't get here.")
          else
            require "#{e}.pb"
            logger.debug("#{class_name} Loaded from #{e}.pb.rb")
            ACL.const_get(class_name).tap do |clazz|
              @@pb_classes[e] = clazz
            end
          end
        end
      end
    end

    class Payload
      include Logger

      include ClassMethods
      extend ClassMethods

      def initialize(encoder=:default)
        @type = encoder
        @clazz = encoder_class(encoder)
      end

      def content(*content, &block)
        if content.empty?
          raise ArgumentError, "No block given" if block.nil?
          @encoder = @clazz.new
          block.call(@encoder)
        else
          @encoder = @clazz.new(content.first)
        end
        self
      end

      # The type of encoder.
      def type
        @type.to_s
      end

      def payload
        @encoder
      end

      # Returns a hash of the payload.
      def to_hash
        @encoder.to_hash
      end

      # Encode the message, returning the encoded data.
      def encode
        @encoder.serialize_to_string
      end

      # Returns true if the payload has all its required fields set.
      def initialized?
        @encoder.initialized?
      end

      # Convert the payload to a pretty string.
      def to_s
        "[#{type}] -> #{(@encoder.respond_to?(:to_hash)) ? @encoder.to_hash : @encoder.to_s}"
      end

      # Decode the message using the specified decoder.
      def self.decode(payload, decoder=:default)
        encoder_class(decoder).new.parse_from_string(payload)
      end
    end
  end
end
