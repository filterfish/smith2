# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Sender < Endpoint

      def initialize(queue_name, queue_opts={})

        # These should probably go into the endpoint.
        @auto_ack = queue_opts.delete(:auto_ack) || true
        @threading = queue_opts.delete(:threading) || false

        set_sender_options
        super
      end

      def publish(message, opts={}, &block)
        _publish(message, @normal_publish_options.merge(opts), &block)
      end

      def publish_and_receive(message, opts={}, &block)
        message_id = random

        Receiver.new(message_id, :auto_ack => @auto_ack, :threading => @threading).ready do |receiver|
          receiver.subscribe do |metadata,payload,responder|

            if metadata.correlation_id != message_id
              logger.error("Incorrect correlation_id: #{metadata.correlation_id}")
            end

            # TODO This should probably go in #threading (see Receiver#threading).
            block.call(metadata, payload)

            metadata.channel.consumers.each do |k,v|
              logger.verbose("Cancelling: #{k}")
              v.cancel
            end
          end

          options = {:reply_to => message_id, :message_id => message_id}.merge(opts)
          _publish(message, @receive_publish_options.merge(options))
        end
      end

      def _publish(message, opts={}, &block)
        logger.verbose("Publishing to: #{queue.name} #{queue.opts}: #{message.inspect}")
        exchange.publish(message.encode, {:routing_key => queue.name, :type => message.encoder.to_s}.merge(opts), &block)
      end

      private

      def set_sender_options
        @normal_publish_options = Smith.config.amqp.publish._child
        @receive_publish_options = Smith.config.amqp.publish._child.merge(:exclusive => true)
      end
    end
  end
end
