# -*- encoding: utf-8 -*-
module Smith

  module ACL
    module ACLInstanceMethods
      def inspect
        "<#{self.class.to_s}> -> #{self.to_hash}"
      end

      def to_json
        MultiJson.dump(self.to_hash)
      end
    end

    class Factory
      include Logger

      @@acl_classes = {:default => Default}

      class << self
        def create(type, content=nil, &blk)
          type = type.to_s

          unless @@acl_classes.include?(type)
            logger.debug { "Loading ACL: #{type}" }
            # decorate the ACL class
            @@acl_classes[type] = clazz(type).send(:include, ACLInstanceMethods)
            @@acl_classes[type].send(:define_method, :_type) { type }
          end

          if blk
            if content.nil?
              @@acl_classes[type].new.tap { |m| blk.call(m) }
            else
              raise ArgumentError, "You cannot give a content hash and a block."
            end
          else
            if content.respond_to?(:serialize_to_string)
              content
            elsif content.nil?
              @@acl_classes[type].new
            else
              @@acl_classes[type].new(content)
            end
          end
        end

        def clazz(type)
          type.split(/::/).inject(ACL) do |a,m|
            a.const_get(Extlib::Inflection.camelize(m))
          end
        end
      end
    end

    class Payload
      include Logger

      # content can be an existing ACL class.
      def initialize(acl, opts={})
        if acl.respond_to?(:serialize_to_string)
          @acl = acl
        else
          raise ArgumentError, "ACL does not have a serialize_to_string method."
        end
      end

      # The type of content.
      def _type
        @acl._type
      end

      # Returns a hash of the payload.
      def to_hash
        @acl.to_hash
      end

      # Encode the content, returning the encoded data.
      def encode
        @acl.serialize_to_string
      end

      # Returns true if the payload has all its required fields set.
      def initialized?
        raise RuntimeError, "You probably forgot to call #content or give the :from option when instantiating the object." if @acl.nil?
        @acl.initialized?
      end

      # Convert the payload to a pretty string.
      def to_s
        @acl.inspect
      end

      # Decode the content using the specified decoder.
      def self.decode(payload, type=:default)
        Factory.create(type).parse_from_string(payload)
      end
    end
  end
end
