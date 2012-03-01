# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Endpoint
      include Logger

      attr_accessor :denomalized_queue_name, :queue_name

      def initialize(queue_name, options)
        @denomalized_queue_name = queue_name
        @queue_name = normalise(queue_name)
        @message_counts = Hash.new(0)
        @options = options
      end

      def ready(&blk)
        Smith.channel.direct(@queue_name, options.exchange) do |exchange|
          @exchange = exchange

          exchange.on_return do |basic_return,metadata,payload|
            logger.error { "#{ACL::Payload.decode(payload.clone, metadata.type)} was returned! Exchange: #{reply_code.exchange}, reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}" }
            logger.error { "Properties: #{metadata.properties}" }
          end

          logger.verbose { "Creating queue: [queue]:#{denomalized_queue_name} [options]:#{options.queue}" }

          Smith.channel.queue(queue_name, options.queue) do |queue|
            @queue = queue
            @options.queue_name = queue_name
            queue.bind(exchange, :routing_key => queue_name)
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

      # Return the total number of messages sent or received for the named queue.
      def counter
        @message_counts[queue_name]
      end

      def messages?(blk=nil, err=proc {logger.debug { "No messages on #{@denomalized_queue_name}" } })
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

      def consumers?(blk=nil, err=proc {logger.debug { "Nothing listening on #{@denomalized_queue_name}" } })
        number_of_consumers do |n|
          if n > 0
            if blk.respond_to? :call
              blk.call(self)
            else
              yield self
            end
          else
            if err.respond_to? :call
              err.call
            end
          end
        end
      end

      def timeout(timeout, blk=nil, &block)
        cancel_timeout
        blk ||= block
        @timeout = EventMachine::Timer.new(timeout, blk)
      end

      protected

      attr_accessor :exchange, :queue, :options

      def increment_counter(value=1)
        @message_counts[queue_name] += value
      end

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
    end
  end
end
