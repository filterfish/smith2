module Smith
  module Events
    class Collector

      # This class distributes events to all registered listeners.

      include Logger

      # FIXME: This shouldn't be a singleton. I've really painted myself into a
      # corner with the current AgentCache and AgentProcess and they are going
      # to be replaced soon which is going to be quite some work. In the mean
      # time I'm make this class a singleton. I don't want to but I don't see
      # any other option.
      include Singleton

      # For every registered listener add an event to the queue.
      #
      # @param [Smith::ACL::Events::*] event Push an event to each registered listener
      def push(event)
        handlers.each do |(identifier, handler)|
          logger.verbose { "Updating: #{identifier}, with event: #{event.class}" }
          handler.call(event)
        end
      end

      alias :<< :push

      # Register a handler to consumer events. The event is passed into the block
      # NOTE: if there are no handlears all events will discarded.
      #
      # @param [Symbol] identifier A unique identifier. If an identifier already
      #   exists the handler will be overwriten by the new block
      #
      # @yeieldparam [Smith::ACL::Events::*] the event
      #
      def register(identifier, &blk)
        handlers[identifier] = blk
      end

      private

      def handlers
        @handlers ||= {}
      end
    end
  end
end
