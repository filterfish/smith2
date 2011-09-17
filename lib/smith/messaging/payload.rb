module Smith
  module Messaging

    module ClassMethods
      include Extlib

      def encoder_class(e)
        Encoder.const_get((e.is_a?(Symbol)) ? Inflection.camelize(e) : e.to_s.split(/::/).last)
      end
    end

    class Payload
      include Logger

      include ClassMethods
      extend ClassMethods

      def initialize(encoder=Messaging::Encoder::Default)
        @clazz = encoder_class(encoder)
      end


      def content(content)
        @encoder = @clazz.send(:new, content)
      end

      # Returns the encoder class.
      def encoder
        @clazz
      end

      # Encode the message, returning the encoded data.
      def encode
        @encoder.encode
      end

      # Decode the message using the specified decoder.
      def self.decode(payload, decoder=Messaging::Encoder::Default)
        encoder_class(decoder).decode(payload)
      end
    end
  end
end
