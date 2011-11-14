# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Receiver < Endpoint

      include Logger

      attr_reader :auto_ack, :threading

      def initialize(queue_name, opts={})
        @auto_ack = opts.delete(:auto_ack) || true
        @threading = opts.delete(:threading) || false

        set_receiver_options
        super
      end

      def queue_name
        denormalise(@queue.name)
      end

      # Subscribes to a queue and passes the headers and payload into the
      # block. +subscribe+ will automatically acknowledge the message unless
      # the options sets :ack to false.
      def subscribe(opts={}, &block)
        _subscribe(@queue, @normal_subscribe_options.merge(opts), &block)
      end

      # Subscribes to a queue, passing the headers and payload into the block,
      # and publishes the result of the block to the reply_to queue.
      # +subscribe_and_reply+ will automatically acknowledge the message unless
      # the options sets :ack to false.
      def subscribe_and_reply(opts={}, &block)
        _subscribe(@queue, @receive_subscribe_options.merge(opts)) do |metadata,payload,responder|
          if metadata.reply_to
            options = @receive_publish_options.merge(:routing_key => normalise(metadata.reply_to), :correlation_id => metadata.message_id).merge(opts)
            responder.callback do |return_value|
              Sender.new(metadata.reply_to).ready do |sender|
                sender.publish(Payload.new(:default).content(return_value), options)
              end
            end
          else
            # Null responder. If a call on the responder is made log a warning. Something is wrong.
            responder.callback do |return_value|
              logger.error("You are responding to a message that has no reply_to on queue: #{@queue.name}.")
              logger.verbose("Queue options: #{metadata.exchange}.")
            end
          end

          block.call(metadata, payload, responder)
        end
      end

      def _subscribe(queue, opts, &block)
        if !@queue.subscribed?
          logger.verbose("Subscribing to: #{queue.name} #{queue.opts}")
          queue.subscribe(opts) do |metadata,payload|
            responder = Responder.new
            if payload
              decoded_payload = Payload.decode(payload, metadata.type)
              logger.verbose("Received message on: #{queue.name} #{opts}: #{decoded_payload.inspect}")
              thread(metadata) do
                block.call(metadata, decoded_payload, responder)
              end
            else
              logger.verbose("Received null message on: #{queue}")
            end
          end
        else
          logger.error("Queue is already subscribed too. Not listening on: #{queue_name}")
        end
      end

      # pops a message off the queue and passes the headers and payload
      # into the block. +pop+ will automatically acknowledge the message
      # unless the options sets :ack to false.
      # TODO there needs to be an option here that allows ack to be turned
      # on but this method not actually run the ack. This is needed so that
      # the pop-queue command can get a message of the queue without actually
      # consuming it. This is mightly helpfull for your local BOFH.
      def pop(opts={}, &block)
        @queue.pop(@normal_pop_options.merge(opts)) do |metadata, payload|
          if payload
            block.call(metadata, Payload.decode(payload, metadata.type))
          end
          metadata.ack if @auto_ack
        end
      end

      private

      # Controls whether to use threads or not. Given that I need to ack in the
      # thread (TODO check this) I also need to pass in a flag to say whether
      # to auto ack or not. This is because it can get called twice and we don't
      # want to ack more than once or an error will be thrown.
      def thread(metadata, &block)
        logger.verbose("Threads: #{threading}")
        logger.verbose("auto_ack: #{auto_ack}")
        if @threading
          EM.defer do
            block.call
            metadata.ack if @auto_ack
          end
        else
          block.call
          metadata.ack if @auto_ack
        end
      end

      def set_receiver_options
        @normal_pop_options = Smith.config.amqp.pop._child
        @normal_subscribe_options = Smith.config.amqp.subscribe._child
        @receive_pop_options = Smith.config.amqp.pop._child.merge(:immediate => true, :mandatory => true)
        @receive_subscribe_options = Smith.config.amqp.subscribe._child.merge(:immediate => true, :mandatory => true)

        # We need the publish opts as well.
        @normal_publish_options = Smith.config.amqp.publish._child
        @receive_publish_options = Smith.config.amqp.publish._child.merge(:exclusive => true, :immediate => true, :mandatory => true)
      end
    end
  end
end
