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

      def initialize(message, encoder=Messaging::Encoder::Default)
        @encoder = encoder_class(encoder).send(:new, message)
      end

      def encoder
        @encoder.class
      end

      def encode
        @encoder.encode
      end

      def self.decode(message, encoder=Messaging::Encoder::Default)
        encoder_class(encoder).decode(message)
      end
    end
  end
end
