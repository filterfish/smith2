module Smith
  module Messaging
    class Payload
      def initialize(message, encoder=:default)
        @encoder = Encoder.const_get(Extlib::Inflection.camelize(encoder)).new(message)
      end

      def encoder
        @encoder.class
      end

      def encode
        @encoder.encode
      end

      def self.decode(message, encoder=:default)
        Encoder.const_get(Extlib::Inflection.camelize(encoder)).decode(message)
      end
    end
  end
end
