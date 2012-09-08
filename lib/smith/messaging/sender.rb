# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Sender < Endpoint

      include Logger

      attr_accessor :options

      def initialize(queue_name, opts={})
        @auto_ack = opts.delete(:auto_ack) || true
        @threading = opts.delete(:threading) || false
        super(queue_name, AmqpOptions.new(opts))
      end

      # Publish a message. If the on_reply method has been called it will
      # setup the correct headers so that reply messages can be tracked.
      def publish(message, opts={}, &block)
        if @reply_queue_name
          message_id = random
          @timeout = EventMachine::Timer.new(@timeout_duration, @timeout_proc)

          # Make sure the reply queue has been setup properly. Otherwise
          # you WILL LOSE MESSAGES.
          @completion.completion do
            _publish(message, options.publish(opts, {:reply_to => @reply_queue_name, :message_id => message_id}), &block)
          end
        else
          _publish(message, options.publish(opts), &block)
        end
      end

      # Set up a listener that will receive replies from the published
      # messages. You must publish with intent to reply -- tee he.
      #
      # If you pass in a queue_name the same queue name will get used for
      # every reply. It means that I don't have to create and teardown a
      # new exchange/queue for every message. If no queue_name is given
      # a random one will be assigned.
      def on_reply(reply_queue_name=nil, opts={}, &block)
        @reply_queue_name = reply_queue_name || random
        @completion = EM::Completion.new

        Receiver.new(@reply_queue_name, :auto_delete => true).ready do |receiver|
          receiver.subscribe do |reply|

            # FIXME work out how to implement message_id/correlation_id checking.

            # unless queue.correlation_id_match?
            #   logger.warn { "The correlation_id should match the message id. correlation id is: #{metadata.correlation_id}, it should be #{queue.message_id}." }
            #   @reply_error.call(queue.message_id, metadata.correlation_id)
            # end

            cancel_timeout
            block.call(reply)
          end

          @completion.succeed
        end
      end

      # This gets called if there is a mismatch in the message_id & correlation_id.
      def on_reply_error(&blk)
        @reply_error = blk
      end

      def publish_and_receive(message, &block)
        message_id = random
        Receiver.new(message_id, :auto_delete => true).ready do |receiver|

          receiver.subscribe do |r|
            raise "Incorrect correlation_id: #{metadata.correlation_id}" if r.metadata.correlation_id != message_id

            cancel_timeout

            block.call(r)

            # Cancel the receive queue. Queues get left behind because the reply queue is
            # still listening. By cancelling the consumer it releases the queue and exchange.
            r.metadata.channel.consumers.each do |k,v|
              if k.start_with?(receiver.queue_name)
                logger.verbose { "Cancelling: #{k}" }
                v.cancel
              end
            end
          end

          # DO NOT MOVE THIS OUTSIDE THE READY BLOCK: YOU WILL LOSE MESSAGES. The reason is
          # that a message can be published and responded too before the receive queue is set up.
          _publish(message, options.publish(:reply_to => message_id, :message_id => message_id, :type => message.type))
        end
      end

      def timeout(timeout, blk=nil, &block)
        cancel_timeout
        blk ||= block

        @timeout_duration = timeout
        @timeout_proc = blk
      end

      private

      def cancel_timeout
        @timeout.cancel if @timeout
      end

      def _publish(message, opts, &block)
        logger.verbose { "Publishing to: [queue]: #{denormalised_queue_name}. [options]: #{opts}" }
        logger.verbose { "Payload content: [queue]: #{denormalised_queue_name}, [metadata type]: #{message.type}, [message]: #{message.inspect}" }
        if message.initialized?
          increment_counter
          exchange.publish(message.encode, opts.merge(:type => message.type), &block)
        else
          raise IncompletePayload, "Message is incomplete: #{message.to_s}"
        end
      end
    end
  end
end
