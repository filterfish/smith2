# -*- encoding: utf-8 -*-
module Smith
  module Messaging

    class Sender

      include Logger
      include Util

      def initialize(queue_def, opts={}, &blk)

        # This is for backward compatibility.
        @queue_def = queue_def.is_a?(QueueDefinition) ? queue_def : QueueDefinition.new(queue_def, opts)

        @acl_type_cache = AclTypeCache.instance

        @reply_container = {}

        prefetch = option_or_default(@queue_def.options, :prefetch, Smith.config.agent.prefetch)

        @options = AmqpOptions.new(@queue_def.options)
        @options.routing_key = @queue_def.normalise

        @message_counts = Hash.new(0)

        @exchange_completion = EM::Completion.new
        @queue_completion = EM::Completion.new
        @channel_completion = EM::Completion.new

        open_channel(:prefetch => prefetch) do |channel|
          @channel_completion.succeed(channel)
          exchange_type = opts[:fanout] ? :fanout : :direct
          channel.send(exchange_type, @queue_def.normalise, @options.exchange) do |exchange|

            exchange.on_return do |basic_return,metadata,payload|
              logger.error { "#{@acl_type_cache[metadata.type].new.parse_from_string} returned! Exchange: #{reply_code.exchange}, reply_code: #{basic_return.reply_code}, reply_text: #{basic_return.reply_text}" }
              logger.error { "Properties: #{metadata.properties}" }
            end

            if opts[:fanout]
              @exchange_completion.succeed(exchange)
            else
              channel.queue(@queue_def.normalise, @options.queue) do |queue|
                queue.bind(exchange, :routing_key => @queue_def.normalise)

                @queue_completion.succeed(queue)
                @exchange_completion.succeed(exchange)
              end
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

            #### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ####
            #### TODO if there is a timeout delete   ####
            #### the proc from the @reply_container. ####
            #### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ####
            @reply_container[message_id] = {:reply_proc => @reply_proc, :timeout => @timeout.clone.tap {|t| t.set_timeout(message_id) }}
            _publish(payload, @options.publish(opts, {:reply_to => reply_queue.queue_name, :message_id => message_id}))
          end
        else
          _publish(payload, @options.publish(opts), &blk)
        end
      end

      def on_timeout(timeout=nil, &blk)
        @timeout = Timeout.new(timeout || Smith.config.smith.timeout, &blk)
      end

      # Called if there is a problem serialising an ACL.
      # @yield [blk] block to run when there is an error.
      # @yieldparam [Proc] the publish callback.
      def on_serialisation_error(&blk)
        @on_serialisation_error = blk
      end

      # Set up a listener that will receive replies from the published
      # messages. You must publish with intent to reply -- tee he.
      #
      # If you pass in a queue_name the same queue name will get used for every
      # reply. This means that there are no create and teardown costs for each
      # message. If no queue_name is given a random one will be assigned.
      def on_reply(opts={}, &blk)
        @reply_proc = blk

        @timeout ||= Timeout.new(Smith.config.smith.timeout, :queue_name => @queue_def.denormalise)

        reply_queue = opts.clone.delete(:reply_queue_name) { random("#{@queue_def.denormalise}.") }

        queue_def = QueueDefinition.new(reply_queue, opts.merge(:auto_delete => true, :durable => false))
        logger.debug { "reply queue: #{queue_def.denormalise}" }

        @reply_queue_completion ||= EM::Completion.new.tap do |completion|
          Receiver.new(queue_def) do |queue|
            queue.subscribe do |payload, receiver|
              @reply_container.delete(receiver.correlation_id).tap do |reply|
                if reply
                  reply[:timeout].cancel_timeout
                  reply[:reply_proc].call(payload, receiver)
                else
                  receiver.ack if opts[:auto_ack]
                  logger.error { "No reply block for correlation_id: #{receiver.correlation_id}. This is probably a timed out message. Message: #{payload.to_json}" }
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
        @message_counts[@queue_def.denormalise]
      end

      # Define a channel error handler.
      def on_error(chain=false, &blk)
        @channel_completion.completion do |channel|
          channel.on_error(&blk)
        end
      end

      def queue_name
        @queue_def.denormalise
      end

      private

      def _publish(message, opts, &blk)
        logger.verbose { "Publishing to: [queue]: #{@queue_def.denormalise}. [options]: #{opts}" }
        logger.verbose { "ACL content: [queue]: #{@queue_def.denormalise}, [metadata type]: #{message.class}, [message]: #{message.inspect}" }

        increment_counter

        type = @acl_type_cache.get_by_type(message.class)

        @exchange_completion.completion do |exchange|
          begin
            exchange.publish(message.to_s, opts.merge(:type => type), &blk)
          rescue Protobuf::SerializationError => e
            if @on_serialisation_error
              @on_serialisation_error.call(e, blk)
            else
              raise ACL::Error.new(e)
            end
          end
        end
      end

      def increment_counter(value=1)
        @message_counts[@queue_def.denormalise] += value
      end
    end

    class Timeout
      def initialize(timeout, opts={}, &blk)
        @timeout_proc = blk || proc { |message_id| raise MessageTimeoutError, "Message not received within the timeout period#{(message_id) ? ": #{message_id}" : ""}" }
        @timeout_duration = timeout
      end

      def set_timeout(message_id)
        @message_id = message_id
        cancel_timeout
        if @timeout_duration
          @timeout = EventMachine::Timer.new(@timeout_duration) do
            @timeout_proc.call(message_id, @timeout_duration)
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

      def to_s
        "<Smith::Timeout: #{@timeout_duration}>"
      end
    end
  end
end
