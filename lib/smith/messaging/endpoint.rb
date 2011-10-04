# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Endpoint
      include Logger

      def initialize(queue_name, queue_opts={})
        set_endpoint_options(queue_name, queue_opts)
      end

      def ready(&blk)
        AMQP::Channel.new(Smith.connection) do |channel|

          # Set up QOS. If you do not do this then the subscribe in receive_message
          # will get overwelmd and the whole thing will collapse in on itself.
          channel.prefetch(1)

          # Set up auto-recovery. This will ensure that the AMQP gem reconnects each
          # channel and sets up the various exchanges & queues.
          channel.auto_recovery = true

          channel.direct(@queue_name, @exchange_options) do |exchange|
            @exchange = exchange

            exchange.on_return do |br, metadata, payload|
              logger.error("#{Payload.decode(payload.clone, :default)} was returned! reply_code = #{br.reply_code}, reply_text = #{br.reply_text}")
            end

            logger.verbose("Creating queue: #{@queue_name} with options: #{@queue_options}")

            channel.queue(@queue_name, @queue_options) do |queue|
              @queue = queue
              queue.bind(exchange, :routing_key => @queue_name)
              blk.call(self)
            end
          end
        end
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

      def consumers?(blk=nil, err=proc {logger.debug("Nothing listening on #{@queue.name}")})
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

      attr_accessor :exchange, :queue, :queue_options

      def normalise(name)
        "#{Smith.config.smith.namespace}.#{name}"
      end

      private

      def random(prefix = '', suffix = '')
        "#{prefix}#{SecureRandom.hex(8)}#{suffix}"
      end

      def set_endpoint_options(queue_name, queue_opts)
        @queue_name = normalise(queue_name)
        amqp_options = Smith.config.amqp
        @exchange_options = amqp_options.exchange._child
        @queue_options = amqp_options.queue._child.merge(queue_opts)
      end
    end
  end
end
