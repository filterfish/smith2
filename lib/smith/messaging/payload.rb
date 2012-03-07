# -*- encoding: utf-8 -*-
module Smith
  module ACL

    module ACLInstanceMethods
      def inspect
        "<#{self.class.to_s}> -> #{(self.respond_to?(:to_hash)) ? self.to_hash : self.to_s}"
      end
    end

    module ClassMethods
      def encoder_class(e)
        @@pb_classes ||= {:default => Default}

        e = e.to_sym

        if @@pb_classes.include?(e)
          @@pb_classes[e]
        else
          class_name = Extlib::Inflection.camelize(e)
          if ACL.constants.include?(class_name)
            logger.error { "Shouldn't get here." }
          else
            require "#{e}.pb"
            logger.debug { "#{class_name} Loaded from #{e}.pb.rb" }
            ACL.const_get(class_name).tap do |clazz|
              # Override the inspect method
              @@pb_classes[e] = clazz.send(:include, ACLInstanceMethods)
            end
          end
        end
      end
    end

    class Payload
      include Logger

      include ClassMethods
      extend ClassMethods

      # content can be an existing ACL class.
      def initialize(type=:default, opts={})
        if opts[:from]
          @type = opts[:from].class.to_s.split(/::/).last.snake_case
          @encoder = opts[:from]
        else
          @type = type
          @clazz = encoder_class(type)
        end
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
        raise RuntimeError, "You probably forgot to call #content or give the :from option when instantiating the object." if @encoder.nil?
        @encoder.initialized?
      end

      # Convert the payload to a pretty string.
      def to_s
        @encoder.inspect
      end

      # Decode the message using the specified decoder.
      def self.decode(payload, decoder=:default)
        encoder_class(decoder).new.parse_from_string(payload)
      end
    end
  end
end
