# -*- encoding: utf-8 -*-
module Smith
  module Messaging

    module Util

      def number_of_messages
        status do |num_messages, _|
          yield num_messages
        end
      end

      def number_of_consumers
        status do |_, num_consumers|
          yield num_consumers
        end
      end

      private

      include AmqpErrors
      include Logging

      def open_channel(opts={}, &blk)
        AMQP::Channel.new(Smith.connection) do |channel,ok|
          logger.verbose { "Opened channel: #{"%x" % channel.object_id}" }

          # Set up auto-recovery. This will ensure that amqp will
          # automatically reconnet to the broker if there is an error.
          channel.auto_recovery = true
          logger.verbose { "Channel auto recovery set to ture" }

          # Set up QOS. If you do not do this then any subscribes will get
          # overwhelmed if there are too many messages.
          prefetch = opts[:prefetch] || Smith.config.agent.prefetch

          channel.prefetch(prefetch)
          logger.verbose { "AMQP prefetch set to: #{prefetch}" }

          blk.call(channel)
        end
      end

      def normalise(name)
        "#{Smith.config.smith.namespace}.#{name}"
      end

      def random(prefix = '', suffix = '')
        "#{prefix}#{SecureRandom.hex(8)}#{suffix}"
      end

      # Return the queue name and options based on whether the
      # queue_definition is of type QueueDefinition.
      def get_queue_name_and_options(queue_definition, opts)
        (queue_definition.is_a?(QueueDefinition)) ? queue_definition.to_a : [queue_definition, opts]
      end

      def option_or_default(options, key, default, &blk)
        if options.is_a?(Hash)
          if options.key?(key)
            v = options.delete(key)
            (blk) ? blk.call(v) : v
          else
            default
          end
        else
          raise ArguementError, "Options must be a Hash."
        end
      end
    end
  end
end
