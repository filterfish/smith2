# -*- encoding: utf-8 -*-
module Smith
  module ACL

    module ClassMethods
      def encoder_class(e)
        @@pb_classes ||= {:default => Default, :agency_command => AgencyCommand}

        e = e.to_sym

        if @@pb_classes.include?(e)
          logger.debug("Using: #{e}") if logger.level = :debug
          @@pb_classes[e]
        else
          class_name = Extlib::Inflection.camelize(e)
          if ACL.constants.include?(class_name)
            logger.error("Shouldn't get here.")
          else
            load "#{e}.pb.rb"
            logger.debug("#{class_name} Loaded from #{e}.pb.rb")
            ACL.const_get(class_name) do |clazz|
              @@pb_classes << class_name
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

      def content(content)
        @encoder = @clazz.send(:new, content)
        self
      end

      # The type of encoder as a string
      def type
        @type.to_s
      end

      # Encode the message, returning the encoded data.
      def encode
        @encoder.encode
      end

      # Decode the message using the specified decoder.
      def self.decode(payload, decoder=:default)
        encoder_class(decoder).decode(payload)
      end
    end
  end
end
