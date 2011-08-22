module Smith
  module Messaging
    class Endpoint
      def initialize(queue_name, encoder=Encoder, queue_opts={})
        extend encoder

        set_endpoint_options

        @channel = AMQP::Channel.new(Smith.connection)

        # Set up QOS. If you do not do this then the subscribe in receive_message
        # will get overwelmd and the whole thing will collapse in on itself.
        @channel.prefetch(1)

        @channel.on_error do |channel, channel_close|
          Smith.stop(true)
        end

        normalised_queue_name = normalise(queue_name)
        @exchange = @channel.direct(normalised_queue_name, @exchange_options)
        @queue = @channel.queue(normalised_queue_name, @queue_options.merge(queue_opts))

        @queue.bind(@exchange, :routing_key => normalised_queue_name)
      end

      def number_of_messages
        @queue.status do |num_messages, num_consumers|
          yield num_messages
        end
      end

      def number_of_consumers
        @queue.status do |num_messages, num_consumers|
          yield num_consumers
        end
      end

      def consumers?(blk=nil, err=proc {logger.debug("Nothing listening on #{queue_name}")})
        number_of_consumers do |n|
          if n > 0
            if blk.respond_to? :call
              blk.call(self)
            else
              yield self
            end
          else
            err.call
          end
        end
      end

      protected

      attr_accessor :exchange, :queue

      def normalise(name)
        "#{Smith.config.smith.namespace}.#{name}"
      end

      private

      def random(prefix = '', suffix = '')
        "#{prefix}#{SecureRandom.hex(8)}#{suffix}"
      end

      def set_endpoint_options
        amqp_options = Smith.config.amqp
        @exchange_options = amqp_options.exchange._child
        @queue_options = amqp_options.queue._child
      end
    end
  end
end
