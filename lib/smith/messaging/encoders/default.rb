# -*- encoding: utf-8 -*-
module Smith
  module ACL

    # Default message. This takes any objuct that can be marshalled. If
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
        @message.inspect
      end

      def method_missing(method, args)
        index = method.to_s.sub(/=$/, '').to_sym
        @message[index] = args
      end
    end
  end
end
