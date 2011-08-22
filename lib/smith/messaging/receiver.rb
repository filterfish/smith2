module Smith
  module Messaging
    class Receiver < Endpoint

      def initialize(queue_name, encoder=Encoder, queue_opts={})
        super
        set_receiver_options
      end

      def subscribe(opts={}, &block)
        if !@queue.subscribed?
          options = @normal_subscribe_options.merge(opts)
          @queue.subscribe(options) do |metadata,payload|
            reply_payload = nil
            if payload
              reply_payload = block.call(metadata, decode(payload))
              metadata.ack if options[:ack]
            end
            reply_payload
          end
        else
          logger.error("Queue is already subscribed too. Not listening on: #{queue_name}")
        end
      end

      def subscribe_and_reply(opts={}, &block)
        reply_payload = subscribe(@receive_subscribe_options.merge(opts)) do |metadata,payload|
          options = @receive_publish_options.merge(:routing_key => normalise(metadata.reply_to), :correlation_id => metadata.message_id).merge(opts)
          Smith::Messaging::Sender.new(metadata.reply_to).publish(block.call(metadata,payload))
        end
      end

      def pop(opts={}, &block)
        @queue.pop(@normal_pop_options.merge(opts)) do |metadata, payload|
          if payload
            block.call(metadata, decode(payload))
            metadata.ack if options[:ack]
          end
        end
      end

      private

      def set_receiver_options
        @normal_pop_options = Smith.config.amqp.pop._child
        @normal_subscribe_options = Smith.config.amqp.subscribe._child
        @receive_pop_options = Smith.config.amqp.pop._child.merge(:immediate => true, :mandatory => true)
        @receive_subscribe_options = Smith.config.amqp.subscribe._child.merge(:immediate => true, :mandatory => true)

        # We need the publish opts as weel.
        @normal_publish_options = Smith.config.amqp.publish._child
        @receive_publish_options = Smith.config.amqp.publish._child.merge(:exclusive => true, :immediate => true)
      end
    end
  end
end
