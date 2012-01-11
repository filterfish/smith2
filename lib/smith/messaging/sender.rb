# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Sender < Endpoint

      include Logger

      attr_accessor :options

      def initialize(queue_name, opts={})

        # These should probably go into the endpoint.
        @auto_ack = opts.delete(:auto_ack) || true
        @threading = opts.delete(:threading) || false
        super(queue_name, AmqpOptions.new(opts))
      end

      def publish(message, opts={}, &block)
        _publish(message, options.publish({:type => message.type}, opts) , &block)
      end

      def publish_and_receive(message, &block)
        message_id = random
        Receiver.new(message_id, :auto_delete => true).ready do |receiver|

          receiver.subscribe do |r|
            if r.metadata.correlation_id != message_id
              logger.error("Incorrect correlation_id: #{metadata.correlation_id}")
            end

            cancel_timeout

            block.call(r)

            # Cancel the receive queue. Queues get left behind because the reply queue is
            # still listening. By cancel'ling the consumer it releases the queue and exchange.
            r.metadata.channel.consumers.each do |k,v|
              if k.start_with?(receiver.queue_name)
                logger.verbose("Cancelling: #{k}")
                v.cancel
              end
            end
          end

          # Do not move this outside the ready block. If you do this it is
          # possible (in fact likely) that you will lose messages. The reason
          # is that a message can be published and responded to before the
          # receive queue is set up.
          _publish(message, options.publish(:reply_to => message_id, :message_id => message_id, :type => message.type))
        end
      end

      private

      def _publish(message, opts, &block)
        logger.verbose("Publishing to: [queue]:#{denomalized_queue_name} [message]: #{message} [options]:#{opts}")
        if message.initialized?
          increment_counter
          exchange.publish(message.encode, opts, &block)
        else
          logger.error("Payload contains required fields that are not set. Not sending message: #{message}")
          raise IncompletePayload, "Message is incomplete: #{message.to_s}"
        end
      end
    end
  end
end
