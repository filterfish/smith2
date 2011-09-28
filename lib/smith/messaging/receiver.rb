# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Receiver < Endpoint

      include Logger

      def initialize(queue_name, queue_opts={})
        super
        set_receiver_options
      end

      # Subscribes to a queue and passes the headers and payload into the
      # block. +subscribe+ will automatically acknowledge the message unless
      # the options sets :ack to false.
      def subscribe(opts={}, &block)
        if !@queue.subscribed?
          options = @normal_subscribe_options.merge(opts)
          @queue.subscribe(options) do |metadata,payload|
            reply_payload = nil
            if payload
              reply_payload = block.call(metadata, Payload.decode(payload, metadata.type))
              metadata.ack if options[:ack]
            end
            reply_payload
          end
        else
          logger.error("Queue is already subscribed too. Not listening on: #{queue_name}")
        end
      end

      # Subscribes to a queue, passing the headers and payload into the block,
      # and publishes the result of the block to the reply_to queue.
      # +subscribe_and_reply+ will automatically acknowledge the message unless
      # the options sets :ack to false. If the reply_to queue is not set a
      # +NoReplyTo+ exception is thrown.

      def subscribe_and_reply(opts={}, &block)
        reply_payload = subscribe(@receive_subscribe_options.merge(opts)) do |metadata,payload|
          if metadata.reply_to
            options = @receive_publish_options.merge(:routing_key => normalise(metadata.reply_to), :correlation_id => metadata.message_id).merge(opts)
            Sender.new(metadata.reply_to).publish(Payload.new.content(block.call(metadata, payload)), options)
          else
            logger.warn("No reply_to queue set for: #{@queue.name}: #{metadata.exchange}")
            block.call(metadata, payload)
          end
        end
      end

      # pops a message off the queue and passes the headers and payload
      # into the block. +pop+ will automatically acknowledge the message
      # unless the options sets :ack to false.
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
