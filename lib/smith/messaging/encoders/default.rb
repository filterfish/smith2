# -*- encoding: utf-8 -*-
module Smith
  module ACL
    class Default
      def initialize(message)
        @message = message
      end

      def encode
        Marshal.dump(@message)
      end

      def self.decode(message)
        Marshal.load(message)
      end
    end
  end
end
