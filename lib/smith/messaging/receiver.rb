# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Receiver < Endpoint

      include Logger

      attr_accessor :options

      def initialize(queue_name, opts={})
        @auto_ack = (opts.has_key?(:auto_ack)) ? opts.delete(:auto_ack) : true
        @threading = (opts.has_key?(:threading)) ? opts.delete(:threading) : false
        @payload_type = (opts.key?(:payload_type)) ? [opts.delete(:payload_type)].flatten : []

        super(queue_name, AmqpOptions.new(opts))
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
              if @payload_type.empty? || @payload_type.include?(metadata.type)
                message = ACL::Payload.decode(payload, metadata.type)
                logger.verbose("Received message on: [queue]:#{denomalized_queue_name} [message]: #{message} [options]:#{opts}")
                increment_counter
                thread(Reply.new(self, metadata, message)) do |reply|
                  block.call(reply)
                end
              else
                raise IncorrectPayloadType, "This queue can only accept the following payload types: #{@payload_type.to_a.to_s}"
              end
            else
              logger.verbose("Received null message on: #{denomalized_queue_name} [options]:#{opts}")
            end
          end
        else
          logger.error("Queue is already subscribed too. Not listening on: #{denormalise_queue_name}")
        end
      end

      # pops a message off the queue and passes the headers and payload
      # into the block. +pop+ will automatically acknowledge the message
      # unless the options sets :ack to false.
      def pop(&block)
        opts = options.pop
        @queue.pop(opts) do |metadata, payload|
          message = ACL::Payload.decode(payload, metadata.type)
          if payload
            thread(Reply.new(self, metadata, message)) do |reply|
              block.call(reply)
            end
          end
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
      def thread(reply, &block)
        logger.verbose("Threads: [queue]: #{denomalized_queue_name}: #{threading?}")
        logger.verbose("auto_ack: [queue]: #{denomalized_queue_name}: #{auto_ack?}")
        if threading?
          EM.defer do
            block.call(reply)
            reply.ack if auto_ack?
          end
        else
          block.call(reply)
          reply.ack if auto_ack?
        end
      end

      class Reply

        include Logger

        attr_reader :metadata, :payload, :time

        def initialize(receiver, metadata, payload)
          @receiver = receiver
          @metadata = metadata
          @payload = payload
          @time = Time.now
        end

        # acknowledge the message.
        def ack(multiple=false)
          @metadata.ack(multiple)
        end

        # reject the message. Optionally requeuing it.
        def reject(opts={})
          @metadata.reject(opts)
        end

        # Reply to a message. If reply_to header is not set a error will be logged
        def reply(&block)
          responder = Responder.new
          if @metadata.reply_to
            responder.callback do |return_value|
              Sender.new(@metadata.reply_to, :auto_delete => true).ready do |sender|
                logger.verbose("Replying on: #{@metadata.reply_to}") if logger.level == 0
                sender.publish(ACL::Payload.new(:default).content(return_value), sender.options.publish(:correlation_id => @metadata.message_id))
              end
            end
          else
            # Null responder. If a call on the responder is made log a warning. Something is wrong.
            responder.callback do |return_value|
              logger.error("You are responding to a message that has no reply_to on queue: #{queue_name}.")
              logger.verbose("Queue options: #{@metadata.exchange}.")
            end
          end

          block.call(responder)
        end

        # The payload type. This returns the protocol buffers class name as a string.
        def payload_type
          @metadata.type
        end

        def queue_name
          @receiver.denomalized_queue_name
        end
      end
    end
  end
end
