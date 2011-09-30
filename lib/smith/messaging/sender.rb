# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Sender < Endpoint

      def initialize(queue_name, queue_opts={})
        super
        set_sender_options
        @queue_name = queue_name
      end

      def publish(message, opts={}, &block)
        logger.verbose("Publishing to: #{@queue.name}: #{message.inspect}")
        options = @normal_publish_options.merge(:routing_key => @queue.name, :type => message.encoder.to_s).merge(opts)
        exchange.publish(message.encode, options, &block)
      end

      def publish_and_receive(message, opts={}, &block)
        message_id = random
        Receiver.new(message_id).subscribe do |metadata,payload|
          block.call(metadata, payload)
        end

        options = {:reply_to => message_id, :message_id => message_id}.merge(opts)
        publish(message, @receive_publish_options.merge(options))
      end

      private

      def set_sender_options
        @normal_publish_options = Smith.config.amqp.publish._child
        @receive_publish_options = Smith.config.amqp.publish._child.merge(:exclusive => true)
      end
    end
  end
end
