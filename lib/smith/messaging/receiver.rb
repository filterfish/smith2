# -*- encoding: utf-8 -*-

require_relative 'message_counter'
require_relative 'requeue'

module Smith
  module Messaging
    class Receiver

      include Logger
      include Util

      attr_accessor :queue_name

      def initialize(queue_name, opts={}, &blk)
        @queue_name = queue_name
        @normalised_queue_name = normalise(queue_name)

        @foo_options = {
          :auto_ack => option_or_default(opts, :auto_ack, true),
          :threading => option_or_default(opts, :threading, false)}

        @payload_type = option_or_default(opts, :type, []) {|v| [v].flatten }

        prefetch = option_or_default(opts, :prefetch, Smith.config.agent.prefetch)

        @options = AmqpOptions.new(opts)
        @options.routing_key = @normalised_queue_name

        @message_counter = MessageCounter.new(queue_name)

        @queue_completion = EM::Completion.new
        @exchange_completion = EM::Completion.new
        @requeue_options_completion = EM::Completion.new

        @reply_queues = {}

        open_channel(:prefetch => prefetch) do |channel|
          channel.direct(@normalised_queue_name, @options.exchange) do |exchange|
            @exchange_completion.succeed(exchange)
          end
        end

        open_channel(:prefetch => prefetch) do |channel|
          channel.queue(@normalised_queue_name, @options.queue) do |queue|
            @exchange_completion.completion do |exchange|
              queue.bind(exchange, :routing_key => @queue_name)
              @queue_completion.succeed(queue)
              @requeue_options_completion.succeed(:exchange => exchange, :queue => queue)
            end
          end
        end

        blk.call(self) if blk

        start_garbage_collection
      end

      def start_garbage_collection
        logger.debug { "Starting the garbage collector." }
        EM.add_periodic_timer(20) do
          @reply_queues.each do |queue_name,queue|
            queue.status do |number_of_messages, number_of_consumers|
              if number_of_messages == 0 && number_of_consumers == 0
                queue.delete do |delete_ok|
                  @reply_queues.delete(queue_name)
                  logger.debug { "Unused reply queue deleted: #{queue_name}" }
                end
              end
            end
          end
        end
      end

      private :start_garbage_collection

      def setup_reply_queue(reply_queue_name, &blk)
        if @reply_queues[reply_queue_name]
          blk.call(@reply_queues[reply_queue_name])
        else
          @exchange_completion.completion do |exchange|
            puts "Attaching to reply queue: #{reply_queue_name}"
            Smith::Messaging::Sender.new(reply_queue_name, :auto_delete => false, :immediate => true, :mandatory => true) do |sender|
              @reply_queues[reply_queue_name] = sender
              blk.call(sender)
            end
          end
        end
      end

      # Subscribes to a queue and passes the headers and payload into the
      # block. +subscribe+ will automatically acknowledge the message unless
      # the options sets :ack to false.
      def subscribe(&blk)
        @queue_completion.completion do |queue|
          @requeue_options_completion.completion do |requeue_options|
            if !queue.subscribed?
              opts = @options.subscribe
              logger.debug { "Subscribing to: [queue]:#{@queue_name} [options]:#{opts}" }
              queue.subscribe(opts) do |metadata,payload|
                if payload
                  on_message(metadata, payload, requeue_options, &blk)
                else
                  logger.verbose { "Received null message on: #{@queue_name} [options]:#{opts}" }
                end
              end
            else
              logger.error { "Queue is already subscribed too. Not listening on: #{@queue_name}" }
            end
          end
        end
      end

      # pops a message off the queue and passes the headers and payload
      # into the block. +pop+ will automatically acknowledge the message
      # unless the options sets :ack to false.
      def pop(&blk)
        opts = @options.pop
        @queue_completion.completion do |queue|
          @requeue_options_completion.completion do |requeue_options|
            queue.pop(opts) do |metadata, payload|
              if payload
                on_message(metadata, payload, requeue_options, &blk)
              end
            end
          end
        end
      end

      def on_message(metadata, payload, requeue_options, &blk)
        if @payload_type.empty? || @payload_type.include?(metadata.type.to_sym)
          @message_counter.increment_counter
          if metadata.reply_to
            setup_reply_queue(metadata.reply_to) do |queue|
              Foo.new(metadata, payload, @foo_options.merge(:reply_queue => queue), requeue_options, &blk)
            end
          else
            Foo.new(metadata, payload, @foo_options, requeue_options, &blk)
          end
        else
          raise IncorrectPayloadType, "This queue can only accept the following payload types: #{@payload_type.to_a.to_s}"
        end
      end

      private :on_message

      def delete(&blk)
        @queue_completion.completion do |queue|
          queue.delete(&blk)
        end
      end

      def status(&blk)
        @queue_completion.completion do |queue|
          queue.status do |num_messages, num_consumers|
            blk.call(num_messages, num_consumers)
          end
        end
      end

      def requeue_parameters(opts={})
        @requeue_options_completion.completion do |requeue_options|
          requeue_options.merge!(opts)
        end
      end

      def on_requeue(&blk)
        @requeue_options_completion.completion do |requeue_options|
          requeue_options.merge!(:on_requeue => blk)
        end
      end

      def on_requeue_error(&blk)
        @requeue_options_completion.completion do |requeue_options|
          requeue_options.merge!(:on_requeue_error => blk)
        end
      end
    end


    class Foo
      attr_accessor :metadata

      def initialize(metadata, data, opts={}, requeue_opts, &blk)
        @metadata = metadata
        @reply_queue = opts[:reply_queue]
        @requeue_opts = requeue_opts


        @time = Time.now
        @message = ACL::Payload.decode(data, metadata.type)

        if opts[:threading]
          EM.defer do
            blk.call(@message, self)
            ack if opts[:auto_ack]
          end
        else
          blk.call(@message, self)
          ack if opts[:auto_ack]
        end
      end

      # Send a message to the reply_to queue as specified in the message header.
      def reply(acl=nil, &blk)
        raise ArgumentError, "you cannot supply an ACL and a blcok." if acl && blk
        raise ArgumentError, "you must supply either an ACL or a blcok." if acl.nil? && blk.nil?

        if reply_to
          @reply_queue.publish((blk) ? blk.call : acl, :correlation_id => @metadata.message_id)
        else
          include Logger
          logger.error { "You are replying to a message that has no reply_to: #{@metadata.exchange}." }
        end
      end

      # Requeue the current mesage on the current queue. A requeue number is
      # added to the message header which is used to ensure the correct number
      # of requeues.
      def requeue
        Requeue.new(@message, @metadata, @requeue_opts).requeue
      end

      # acknowledge the message.
      def ack(multiple=false)
        @metadata.ack(multiple)
      end

      # reject the message. Optionally requeuing it.
      def reject(opts={})
        @metadata.reject(opts)
      end
    end
  end
end
