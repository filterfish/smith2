# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Receiver < Endpoint

      include Logger

      attr_accessor :options

      def initialize(queue_name, opts={})
        @auto_ack = (opts.has_key?(:auto_ack)) ? opts.delete(:auto_ack) : true
        @threading = (opts.has_key?(:threading)) ? opts.delete(:threading) : false
        @payload_type = (opts.key?(:type)) ? [opts.delete(:type)].flatten : []

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
              if @payload_type.empty? || @payload_type.include?(metadata.type.to_sym)
                thread(Reply.new(self, metadata, payload)) do |reply|
                  increment_counter
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
          if payload
            thread(Reply.new(self, metadata, payload)) do |reply|
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

      # I'm not terribly happy about this class. It's publicaly visable and it contains
      # some gross violations of Ruby's protection mechanism. I suspect it's an indication
      # of a more fundamental design flaw. I will leave it as is for the time being but
      # this really needs to be reviewed. FIXME review this class.
      class Reply

        include Logger

        attr_reader :metadata, :payload, :time

        def initialize(receiver, metadata, undecoded_payload)
          @undecoded_payload = undecoded_payload
          @receiver = receiver
          @exchange = receiver.send(:exchange)
          @metadata = metadata
          @time = Time.now

          @payload = ACL::Payload.decode(undecoded_payload, metadata.type)
          logger.verbose("Payload content: [queue]: #{denomalized_queue_name} [message]: #{pretty_print_payload(payload)}")
        end

        # acknowledge the message.
        def ack(multiple=false)
          @metadata.ack(multiple)
        end

        # reject the message. Optionally requeuing it.
        def reject(opts={})
          @metadata.reject(opts)
        end

        # Republish the message to the end of the same queue. This is useful
        # for when the agent encounters an error and needs to requeue the message.
        def requeue(delay, &block)
          # Sort out the options.
          opts = @receiver.send(:queue).opts.tap do |o|
            o.delete(:queue)
            o.delete(:exchange)

            o[:headers] = increment_retry_count(metadata.headers)
            o[:routing_key] = normalised_queue_name
            o[:type] = metadata.type
          end

          logger.verbose("Requeuing to: #{denomalized_queue_name}. [options]: #{opts}")
          logger.verbose("Requeuing to: #{denomalized_queue_name}. [message]: #{ACL::Payload.decode(@undecoded_payload, metadata.type)}")

          EM.add_timer(delay) do
            @receiver.send(:exchange).publish(@undecoded_payload, opts)
          end
        end

        def requeue_count
          metadata.headers['retry'] || 0
        end

        # Reply to a message. If reply_to header is not set a error will be logged
        def reply(&block)
          responder = Responder.new
          if reply_to
            responder.callback do |return_value|
              Sender.new(@metadata.reply_to, :auto_delete => true).ready do |sender|
                logger.verbose("Replying on: #{@metadata.reply_to}") if logger.level == 0
                sender.publish(ACL::Payload.new(:default).content(return_value), sender.options.publish(:correlation_id => @metadata.message_id))
              end
            end
          else
            # Null responder. If a call on the responder is made log a warning. Something is wrong.
            responder.callback do |return_value|
              logger.error("You are responding to a message that has no reply_to on queue: #{denomalized_queue_name}.")
              logger.verbose("Queue options: #{@metadata.exchange}.")
            end
          end

          block.call(responder)
        end

        # The payload type. This returns the protocol buffers class name as a string.
        def payload_type
          @metadata.type
        end

        def reply_to
          @metadata.reply_to
        end

        def queue_name
          normalised_queue_name
        end

        private

        def denomalized_queue_name
          @receiver.denomalized_queue_name
        end

        def normalised_queue_name
          @receiver.queue_name
        end

        def increment_retry_count(headers)
          headers.tap do |m|
            m['retry'] = (m['retry']) ? m['retry'] + 1 : 1
          end
        end

        # Pretty print the payload. This should go into the payload but for
        # time being it's going here.
        def pretty_print_payload(payload)
          "[#{payload.class.to_s.split(/::/).last.snake_case}] -> #{(payload.respond_to?(:to_hash)) ? payload.to_hash : payload.to_s}"
        end
      end
    end
  end
end
