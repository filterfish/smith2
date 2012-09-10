# -*- encoding: utf-8 -*-

require 'yajl'

module Smith
  module ACL

    # Default message. This takes any object that can be marshalled. If
    # no content is passed in on the constructor then an the message is
    # assigned an empty Hash. method_missing is declared and will update
    # the hash.
    class Default

      def initialize(message={})
        @message = message
      end

      # Always return true. There is no validation.
      def initialized?
        true
      end

      def serialize_to_string
        Marshal.dump(@message)
      end

      def parse_from_string(message)
        Marshal.load(message)
      end

      def to_s
        @message.to_s
      end

      def to_hash
        @message && @message.to_hash
      end

      def inspect
        "<#{self.class.to_s}> -> #{(self.respond_to?(:to_hash)) ? self.to_hash : self.to_s}"
      end

      def to_json
        Yajl.dump(@message)
      end

      def method_missing(method, args)
        match = /(.*?)=$/.match(method.to_s)
        if match && match[1]
          index = match[1].to_sym
          @message[index] = args
        else
          raise NoMethodError, "undefined method `#{method}' for #{self}", caller
        end
      end
    end
  end
end
