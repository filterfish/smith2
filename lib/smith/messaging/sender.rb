# -*- encoding: utf-8 -*-
module Smith
  module Messaging

    class Sender

      include Logger
      include Util

      attr_accessor :queue_name

      def initialize(queue_definition, opts={}, &blk)

        @queue_name, opts = get_queue_name_and_options(queue_definition, opts)

        @reply_container = {}

        normalised_queue_name = normalise(@queue_name)

        prefetch = option_or_default(opts, :prefetch, Smith.config.agent.prefetch)

        @options = AmqpOptions.new(opts)
        @options.routing_key = normalised_queue_name

        @message_counts = Hash.new(0)

        @exchange_completion = EM::Completion.new
        @queue_completion = EM::Completion.new
        @channel_completion = EM::Completion.new

        open_channel(:prefetch => prefetch) do |channel|
          @channel_completion.succeed(channel)
          channel.direct(normalised_queue_name, @options.exchange) do |exchange|

            exchange.on_return do |basic_return,metadata,payload|
              logger.error { "#{ACL::Payload.decode(payload.clone, metadata.type)} returned! Exchange: #{reply_code.exchange}, reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}" }
              logger.error { "Properties: #{metadata.properties}" }
            end

            channel.queue(normalised_queue_name, @options.queue) do |queue|
              queue.bind(exchange, :routing_key => normalised_queue_name)

              @queue_completion.succeed(queue)
              @exchange_completion.succeed(exchange)
            end
          end
        end

        blk.call(self) if blk
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
      def publish(payload, opts={}, &blk)
        if @reply_queue_completion
          @reply_queue_completion.completion do |reply_queue|
            message_id = random
            logger.verbose { "message_id: #{message_id}" }

            #### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ####
            #### TODO if there is a timeout delete  ####
            #the proc from the @reply_container.    ####
            #### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ####
            @reply_container[message_id] = {:reply_proc => @reply_proc, :timeout => @timeout.clone.tap {|t| t.set_timeout(message_id) }}
            _publish(ACL::Payload.new(payload), @options.publish(opts, {:reply_to => reply_queue.queue_name, :message_id => message_id}))
          end
        else
          _publish(ACL::Payload.new(payload), @options.publish(opts), &blk)
        end
      end

      def on_timeout(timeout, &blk)
        @timeout = Timeout.new(timeout, &blk)
      end

      # Set up a listener that will receive replies from the published
      # messages. You must publish with intent to reply -- tee he.
      #
      # If you pass in a queue_name the same queue name will get used for every
      # reply. This means that there are no create and teardown costs for every
      # for every message. If no queue_name is given a random one will be
      # assigned.
      def on_reply(opts={}, &blk)
        @reply_proc = blk
        @timeout ||= Timeout.new(Smith.config.agency.timeout, :queue_name => @queue_name)
        reply_queue_name = opts.delete(:reply_queue_name) || random

        options = {:auto_delete => false, :auto_ack => false}.merge(opts)

        logger.debug { "reply queue: #{reply_queue_name}" }

        @reply_queue_completion ||= EM::Completion.new.tap do |completion|
          Receiver.new(reply_queue_name, options) do |queue|
            queue.subscribe do |payload, receiver|
              @reply_container.delete(receiver.correlation_id).tap do |reply|
                if reply
                  reply[:timeout].cancel_timeout
                  reply[:reply_proc].call(payload, receiver)
                else
                  logger.error { "Reply message has no correlation_id: #{reply.inspect}" }
                end
              end
            end

            EM.next_tick do
              completion.succeed(queue)
            end
          end
        end
      end

      def delete(&blk)
        @queue_completion.completion do |queue|
          queue.delete do
            @exchange_completion.completion do |exchange|
              exchange.delete do
                @channel_completion.completion do |channel|
                  channel.close(&blk)
                end
              end
            end
          end
        end
      end

      # This gets called if there is a mismatch in the message_id & correlation_id.
      def on_reply_error(&blk)
        @reply_error = blk
      end

      def status(&blk)
        @queue_completion.completion do |queue|
          queue.status do |num_messages, num_consumers|
            blk.call(num_messages, num_consumers)
          end
        end
      end

      def message_count(&blk)
        status do |messages|
          blk.call(messages)
        end
      end

      def consumer_count(&blk)
        status do |_, consumers|
          blk.call(consumers)
        end
      end

      def counter
        @message_counts[@queue_name]
      end

      # Define a channel error handler.
      def on_error(chain=false, &blk)
        @channel_completion.completion do |channel|
          channel.on_error(&blk)
        end
      end

      private

      def _publish(message, opts, &blk)
        logger.verbose { "Publishing to: [queue]: #{@queue_name}. [options]: #{opts}" }
        logger.verbose { "Payload content: [queue]: #{@queue_name}, [metadata type]: #{message._type}, [message]: #{message.inspect}" }
        if message.initialized?
          increment_counter
          type = (message.respond_to?(:_type)) ? message._type : message.type
          @exchange_completion.completion do |exchange|
            exchange.publish(message.encode, opts.merge(:type => type), &blk)
          end
        else
          raise IncompletePayload, "Message is incomplete: #{message.to_s}"
        end
      end

      def increment_counter(value=1)
        @message_counts[@queue_name] += value
      end
    end

    class Timeout
      def initialize(timeout, opts={}, &blk)
        @timeout_proc = blk || proc { |message_id| raise ACLTimeoutError, "Message not received within the timeout period#{(message_id) ? ": #{message_id}" : ""}" }
        @timeout_duration = timeout
      end

      def set_timeout(message_id)
        @message_id = message_id
        cancel_timeout
        if @timeout_duration
          @timeout = EventMachine::Timer.new(@timeout_duration) do
            @timeout_proc.call(message_id)
          end
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
