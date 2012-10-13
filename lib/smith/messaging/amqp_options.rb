# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class AmqpOptions
      include Logger

      attr_accessor :queue_name

      def initialize(options={})
        @options = options
        @options_map = {:strict => {:immediate => true, :mandatory => true}}
      end

      def exchange(*extra_opts)
        merge(Smith.config.amqp.exchange.to_hash, @options, extra_opts)
      end

      def queue(*extra_opts)
        merge(Smith.config.amqp.queue.to_hash, @options, extra_opts)
      end

      def pop(*extra_opts)
        merge(Smith.config.amqp.pop.to_hash, @options, extra_opts)
      end

      def publish(*extra_opts)
        merge(Smith.config.amqp.publish.to_hash, {:routing_key => queue_name}, extra_opts)
      end

      def subscribe(*extra_opts)
        merge(Smith.config.amqp.subscribe.to_hash, extra_opts)
      end

      private

      def expand_options(opts)
        options = opts.inject({}) do |a,(k,v)|
          a.tap do |acc|
            if @options_map.key?(k)
              acc.merge!(@options_map[k])
            else
              acc[k] = v
            end
          end
        end
      end

      def merge(*hashes)
        hashes.flatten.inject({}) do |acc,h|
          acc.merge!(expand_options(h))
        end
      end
    end
  end
end
