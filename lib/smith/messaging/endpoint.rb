module Smith
  module Messaging
    class Endpoint
      def initialize(queue_name, encoder=Encoder, queue_opts={})
        extend encoder

        set_endpoint_options

        @channel = AMQP::Channel.new(Smith.connection)
        @channel.on_error do |channel, channel_close|
          Smith.stop(true)
        end

        normalised_queue_name = normalise(queue_name)
        @exchange = @channel.direct(normalised_queue_name, @exchange_options)
        @queue = @channel.queue(normalised_queue_name, @queue_options.merge(queue_opts))

        @queue.bind(@exchange, :routing_key => normalised_queue_name)
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
