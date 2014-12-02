# -*- encoding: utf-8 -*-

require 'smith'
require 'smith/messaging/util'
require 'bunny'

module Smith
  module Messaging
    class SyncSender

      include Logger
      include Util

      def initialize(queue_def, opts={})
        @queue_def = queue_def.is_a?(QueueDefinition) ? queue_def : QueueDefinition.new(queue_def, opts)
        @acl_type_cache = AclTypeCache.instance

        @options = AmqpOptions.new(@queue_def.options)
        @options.routing_key = @queue_def.normalise

        conn = Bunny.new
        conn.start

        channel = conn.create_channel
        channel.prefetch(option_or_default(@queue_def.options, :prefetch, Smith.config.agent.prefetch))

        queue_name = @queue_def.normalise

        @exchange = channel.direct(@queue_def.normalise, @options.exchange)

        @queue = channel.queue(@queue_def.normalise, @options.queue)
        @queue.bind(@exchange, :routing_key => @queue_def.normalise)
      end

      def publish(acl, opts={})
        opts = {:message_id => random, :type => @acl_type_cache.get_by_type(acl.class), :routing_key => @queue_def.normalise}
        logger.debug { "Publishing to: #{@queue_def.normalise}, opts: #{opts}" }
        @exchange.publish(acl.to_s, opts)
      end
    end
  end
end
