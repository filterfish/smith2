# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Endpoint
      include Logger

      def initialize(queue_name, queue_opts={})
        set_endpoint_options(queue_name, queue_opts)
      end

      def ready(&blk)
        Smith.channel.direct(@queue_name, @exchange_options) do |exchange|
          @exchange = exchange

          exchange.on_return do |basic_return, metadata, payload|
            logger.error("#{Payload.decode(payload.clone, :default)} was returned! reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}")
          end

          logger.verbose("Creating queue: #{@queue_name} with options: #{@queue_options}")

          Smith.channel.queue(@queue_name, @queue_options) do |queue|
            @queue = queue
            queue.bind(exchange, :routing_key => @queue_name)
            blk.call(self)
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

      def messages?(blk=nil, err=proc {logger.debug("No messages on #{@queue.name}")})
        number_of_messages do |n|
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

      def timeout(timeout, blk=nil, &block)
        cancel_timeout
        blk ||= block
        @timeout = EventMachine::Timer.new(timeout, blk)
      end

      protected

      attr_accessor :exchange, :queue, :queue_name, :queue_options

      def denormalise(name)
        name.sub(/#{Regexp.escape("#{Smith.config.smith.namespace}.")}/, '')
      end

      def normalise(name)
        "#{Smith.config.smith.namespace}.#{name}"
      end

      def cancel_timeout
        @timeout.cancel if @timeout
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
