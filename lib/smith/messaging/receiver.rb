# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Receiver < Endpoint

      include Logger

      attr_accessor :options, :message_id

      def initialize(queue_name, opts={})
        @auto_ack = (opts.has_key?(:auto_ack)) ? opts.delete(:auto_ack) : true
        @threading = (opts.has_key?(:threading)) ? opts.delete(:threading) : false
        @payload_type = (opts.key?(:type)) ? [opts.delete(:type)].flatten : []

        @factory = QueueFactory.new

        super(queue_name, AmqpOptions.new(opts))
      end

      # Subscribes to a queue and passes the headers and payload into the
      # block. +subscribe+ will automatically acknowledge the message unless
      # the options sets :ack to false.
      def subscribe(&block)
#        if !@queue.subscribed?
          opts = options.subscribe
          logger.verbose { "Subscribing to: [queue]:#{denormalised_queue_name} [options]:#{opts}" }
          queue.subscribe(opts) do |metadata,payload|
            if payload
              if @payload_type.empty? || @payload_type.include?(metadata.type.to_sym)
                thread(Reply.new(self, metadata, payload, @factory)) do |reply|
                  increment_counter
                  block.call(reply)
                end
              else
                raise IncorrectPayloadType, "This queue can only accept the following payload types: #{@payload_type.to_a.to_s}"
              end
            else
              logger.verbose { "Received null message on: #{denormalised_queue_name} [options]:#{opts}" }
            end
          end
#        else
          # logger.error { "Queue is already subscribed too. Not listening on: #{denormalised_queue_name}" }
#        end
      end

      # pops a message off the queue and passes the headers and payload
      # into the block. +pop+ will automatically acknowledge the message
      # unless the options sets :ack to false.
      def pop(&block)
        opts = options.pop
        @queue.pop(opts) do |metadata, payload|
          thread(Reply.new(self, metadata, (payload.nil?) ? nil : payload), @factory) do |reply|
            block.call(reply)
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
        logger.verbose { "Threads: [queue]: #{denormalised_queue_name}: #{threading?}" }
        logger.verbose { "auto_ack: [queue]: #{denormalised_queue_name}: #{auto_ack?}" }
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

      # I'm not terribly happy about this class. It's publicly visible and it contains
      # some gross violations of Ruby's protection mechanism. I suspect it's an indication
      # of a more fundamental design flaw. I will leave it as is for the time being but
      # this really needs to be reviewed. FIXME review this class.
      class Reply

        attr_reader :metadata, :payload, :time

        def initialize(receiver, metadata, undecoded_payload, factory)
          @undecoded_payload = undecoded_payload
          @receiver = receiver
          @exchange = receiver.send(:exchange)
          @metadata = metadata
          @time = Time.now
          @factory = factory

          if undecoded_payload
            @payload = ACL::Payload.decode(undecoded_payload, metadata.type)
            logger.verbose { "Received content on: [queue]: #{denormalised_queue_name}." }
            logger.verbose { "Payload content: [queue]: #{denormalised_queue_name}, [metadata type]: #{metadata.type}, [message]: #{payload.inspect}" }
          else
            logger.verbose { "Received nil content on: [queue]: #{denormalised_queue_name}." }
            @payload = nil
            @nil_message = true
          end
        end

        # Reply to a message. If reply_to header is not set a error will be logged
        def reply(&block)
          responder = Responder.new
          if reply_to
            responder.callback do |return_value|
              logger.verbose { "Replying on: #{metadata.reply_to}" } if logger.level == 0
              pp metadata.reply_to
              @factory.sender(metadata.reply_to, :auto_delete => true, :immediate => true, :mandatory => true) do |sender|
                pp sender.object_id
                #payload = Smith::ACL::Factory.create(:default, return_value)

                payload = ACL::Payload.new(:default).content(:list => return_value)

                sender.publish(payload, :correlation_id => metadata.message_id)
              end
            end
          else
            # Null responder. If a call on the responder is made log a warning. Something is wrong.
            responder.callback do |return_value|
              logger.error { "You are responding to a message that has no reply_to on queue: #{denormalised_queue_name}." }
              logger.verbose { "Queue options: #{metadata.exchange}." }
            end
          end

          block.call(responder)
        end

        # acknowledge the message.
        def ack(multiple=false)
          metadata.ack(multiple) unless @nil_message
        end

        # reject the message. Optionally requeuing it.
        def reject(opts={})
          metadata.reject(opts) unless @nil_message
        end

        def reply_to
          metadata.reply_to
        end

        # Republish the message to the end of the same queue. This is useful
        # for when the agent encounters an error and needs to requeue the message.
        def requeue(delay, count, strategy, &block)
          requeue_with_strategy(delay, count, strategy) do

            # Sort out the options. Receiver#queue is private hence the send. I know, I know.
            opts = @receiver.send(:queue).opts.tap do |o|
              o.delete(:queue)
              o.delete(:exchange)

              o[:headers] = increment_requeue_count(metadata.headers)
              o[:routing_key] = normalised_queue_name
              o[:type] = metadata.type
            end

            logger.verbose { "Requeuing to: #{denormalised_queue_name}. [options]: #{opts}" }
            logger.verbose { "Requeuing to: #{denormalised_queue_name}. [message]: #{ACL::Payload.decode(@undecoded_payload, metadata.type)}" }

            @receiver.send(:exchange).publish(@undecoded_payload, opts)
          end
        end

        def on_requeue_error(&block)
          @on_requeue_error = block
        end

        def on_requeue(&block)
          @on_requeue = block
        end

        def current_requeue_number
          metadata.headers['requeue'] || 0
        end

        # The payload type. This returns the protocol buffers class name as a string.
        def payload_type
          metadata.type
        end

        def queue_name
          denormalised_queue_name
        end

        # Check that the correlation_id matches the message_id assuming there
        # is a message id! This is only applicable for a message reply.
        # NOTE This is broken.
        def correlation_id_match?
          pp @receiver.message_id, metadata.correlation_id
          !!(@receiver.message_id && metadata.correlation_id == receiver.message_id)
        end

        private

        def requeue_with_strategy(delay, count, strategy, &block)
          if current_requeue_number < count
            method = "#{strategy}_strategy".to_sym
            if respond_to?(method, true)
              cumulative_delay = send(method, delay)
              @on_requeue.call(cumulative_delay, current_requeue_number + 1)
              EM.add_timer(cumulative_delay) do
                block.call(cumulative_delay, current_requeue_number + 1)
              end
            else
              raise RuntimeError, "Unknown requeue strategy. #{method}"
            end
          else
            @on_requeue_error.call(cumulative_delay, current_requeue_number)
          end
        end

        def exponential_no_initial_delay_strategy(delay)
          delay * (2 ** current_requeue_number - 1)
        end

        def exponential_strategy(delay)
          delay * (2 ** current_requeue_number)
        end

        def linear_strategy(delay)
          delay * (current_requeue_number + 1)
        end

        def denormalised_queue_name
          @receiver.denormalised_queue_name
        end

        def normalised_queue_name
          @receiver.queue_name
        end

        def increment_requeue_count(headers)
          headers.tap do |m|
            m['requeue'] = (m['requeue']) ? m['requeue'] + 1 : 1
          end
        end
      end
    end
  end
end
