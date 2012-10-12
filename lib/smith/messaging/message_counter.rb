# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class MessageCounter

      def initialize(queue_name)
        @message_counts = Hash.new(0)
        @queue_name = queue_name
      end

      # Return the total number of messages sent or received for the named queue.
      def counter
        @message_counts[@queue_name]
      end

      def increment_counter(value=1)
        @message_counts[@queue_name] += value
      end
    end
  end
end
