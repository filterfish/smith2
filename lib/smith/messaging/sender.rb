# -*- encoding: utf-8 -*-
module Smith
  module Messaging

    class Sender < Endpoint

      include Logger

      attr_accessor :options

      def initialize(queue_name, opts={})
        @auto_ack = opts.delete(:auto_ack) || true
        @threading = opts.delete(:threading) || false
        @reply_procs = {}

        super(queue_name, AmqpOptions.new(opts))
      end

      # If reply queue is set the block will be called when the message
      # recipient replies to the message and it is received.
      #
      # If a block is passed to this method but the :reply_queue option
      # is not set it will be called when the message has been safely
      # published.
      #
      # If the :reply_queue is an empty string then a random queue name
      # will be generated.
      def new_publish(message, opts={}, &block)
        reply_queue = opts.delete(:reply_queue)

        if @reply_proc
          @reply_queue_completion ||= setup_reply_queue(reply_queue)
          @timeout ||= MessageTimeout.new(20)

          @reply_queue_completion.completion do |receiver|
            receiver.subscribe do |reply|
              logger.debug { "correlation_id: #{reply.metadata.correlation_id}" }

              reply_proc = @reply_procs.delete(reply.metadata.correlation_id)
              if reply_proc
                reply_proc.call(reply)
              else
                logger.error { "Reply message has no correlation_id: #{reply.inspect}" }
              end
            end

            message_id = random
            logger.debug { "message_id: #{message_id}" }

            @reply_procs[message_id] = @reply_proc
            _publish(message, options.publish(opts, {:reply_to => receiver.denormalised_queue_name, :message_id => message_id}))
          end
        else
          _publish(message, options.publish(opts), &block)
        end
      end

      # Publish a message. If the on_reply method has been called it will
      # setup the correct headers so that reply messages can be tracked.
      def publish(message, opts={}, &block)

        # !!!!!!!!!!!!!!!!!!!!!!!!!! Add the message_id to a FIFO so the on_reply
        # !!!!!!!!!!!!!!!!!!!!!!!!!! get match the correlation_id. You probably
        # !!!!!!!!!!!!!!!!!!!!!!!!!! need something to make sure that is doesn't
        # !!!!!!!!!!!!!!!!!!!!!!!!!! get too big.

        if @reply_queue_name
          message_id = random
          @timeout.set_timeout

          # Make sure the reply queue has been setup properly. Otherwise
          # you WILL LOSE messages.
          @completion.completion do
            _publish(message, options.publish(opts, {:reply_to => @reply_queue_name, :message_id => @mesage_ids.next_message_id}), &block)
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
      def on_reply(reply_queue_name=random, opts={}, &block)
        @reply_proc = block
        @reply_queue_completion = EM::Completion.new.tap do |completion|
          Receiver.new(reply_queue_name, :auto_delete => true).ready do |receiver|
            completion.succeed(receiver)
            logger.debug { "Receive queue set up: #{reply_queue_name}" }
          end
        end
      end

      # This gets called if there is a mismatch in the message_id & correlation_id.
      def on_reply_error(&blk)
        @reply_error = blk
      end

      def on_timeout(duration=20, blk=nil, &block)
        blk ||= block
        @timeout = MessageTimeout.new(duration, &blk)
      end

      # Deprecated.
      def publish_and_receive(message, &block)
        message_id = random
        Receiver.new(message_id, :auto_delete => true).ready do |receiver|

          receiver.subscribe do |r|
            raise "Incorrect correlation_id: #{metadata.correlation_id}" if r.metadata.correlation_id != message_id

            @timeout.cancel_timeout if @timeout

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

      private

      def _publish(message, opts, &block)
        logger.verbose { "Publishing to: [queue]: #{denormalised_queue_name}. [options]: #{opts}" }
        logger.verbose { "Payload content: [queue]: #{denormalised_queue_name}, [metadata type]: #{message.type}, [message]: #{message.inspect}" }
        if message.initialized?
          increment_counter
          type = (message.respond_to?(:_type)) ? message._type : message.type
          exchange.publish(message.encode, opts.merge(:type => type), &block)
        else
          raise IncompletePayload, "Message is incomplete: #{message.to_s}"
        end
      end
    end

    class MessageTimeout
      def on_timeout(timeout, &block)
        cancel_timeout
        @timeout_proc = block || proc {raise ACLTimeoutError, "Message not received within the timeout period: #{message_id}"}
        @timeout_duration = timeout
      end

      def set_timeout
        if @timeout_duration
          @timeout = EventMachine::Timer.new(@timeout_duration, @timeout_proc)
        else
          raise ArgumentError, "on_timeout not set."
        end
      end

      def timeout?
        !@timeout_duration.nil?
      end

      def cancel_timeout
        @timeout.cancel if @timeout
      end
    end
  end
end
