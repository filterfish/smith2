# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Receiver < Endpoint

      include Logger

      attr_accessor :options

      def initialize(queue_name, opts={})
        @auto_ack = (opts.has_key?(:auto_ack)) ? opts.delete(:auto_ack) : true
        @threading = (opts.has_key?(:threading)) ? opts.delete(:threading) : false
        super(queue_name, AmqpOptions.new(opts))
        @payloads = {}
      end

      # Subscribes to a queue and passes the headers and payload into the
      # block. +subscribe+ will automatically acknowledge the message unless
      # the options sets :ack to false.
      def subscribe(&block)
        if !@queue.subscribed?
          opts = options.subscribe
          logger.verbose("Subscribing to: [queue]:#{denomalized_queue_name} [options]:#{opts}")
          queue.subscribe(opts) do |metadata,payload|
            if payload
              message = ACL::Payload.decode(payload, metadata.type)
              logger.verbose("Received message on: [queue]:#{denomalized_queue_name} [message]: #{message} [options]:#{opts}")
              increment_counter
              thread(metadata) do
                block.call(metadata, message)
              end
            else
              logger.verbose("Received null message on: #{denomalized_queue_name} [options]:#{opts}")
            end
          end
        else
          logger.error("Queue is already subscribed too. Not listening on: #{denormalise_queue_name}")
        end
      end

      # Reply to a message. If reply_to header is not set a error will be logged
      def reply(metadata, &block)
        responder = Responder.new
        if metadata.reply_to
          responder.callback do |return_value|
            Sender.new(metadata.reply_to).ready do |sender|
              logger.verbose("Replying on: #{metadata.reply_to}") if logger.level == 0

              # Cache the Payload, it does make a difference. TODO check this is valid.
              payload = @payloads[:default] ||= ACL::Payload.new(:default)
              sender.publish(payload.content(return_value), sender.options.publish(:correlation_id => metadata.message_id))
            end
          end
        else
          # Null responder. If a call on the responder is made log a warning. Something is wrong.
          responder.callback do |return_value|
            logger.error("You are responding to a message that has no reply_to on queue: #{denomalized_queue_name}.")
            logger.verbose("Queue options: #{metadata.exchange}.")
          end
        end

        block.call(responder)
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
            block.call(metadata, ACL::Payload.decode(payload, metadata.type))
          end
          metadata.ack if @auto_ack
        end
      end

      def threading?
        @threading
      end

      def auto_ack?
        @auto_ack
      end

      private

      # Controls whether to use threads or not. Given that I need to ack in the
      # thread (TODO check this) I also need to pass in a flag to say whether
      # to auto ack or not. This is because it can get called twice and we don't
      # want to ack more than once or an error will be thrown.
      def thread(metadata, &block)
        logger.verbose("Threads: #{threading?}")
        logger.verbose("auto_ack: #{auto_ack?}")
        if threading?
          EM.defer do
            block.call
            metadata.ack if auto_ack?
          end
        else
          block.call
          metadata.ack if auto_ack?
        end
      end
    end
  end
end
