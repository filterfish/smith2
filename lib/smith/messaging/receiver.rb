# -*- encoding: utf-8 -*-

require_relative 'message_counter'
require_relative 'requeue'

module Smith
  module Messaging
    class Receiver

      include Logger
      include Util

      def initialize(queue_def, opts={}, &blk)

        # This is for backward compatibility.
        @queue_def = queue_def.is_a?(QueueDefinition) ? queue_def : QueueDefinition.new(queue_def, opts)

        @acl_type_cache = AclTypeCache.instance

        @foo_options = {
          :auto_ack => option_or_default(@queue_def.options, :auto_ack, true),
          :threading => option_or_default(@queue_def.options, :threading, false)}

        @payload_type = Array(option_or_default(@queue_def.options, :type, []))

        prefetch = option_or_default(@queue_def.options, :prefetch, Smith.config.agent.prefetch)

        @options = AmqpOptions.new(@queue_def.options)
        @options.routing_key = @queue_def.normalise

        @message_counter = MessageCounter.new(@queue_def.denormalise)

        @channel_completion = EM::Completion.new
        @queue_completion = EM::Completion.new
        @exchange_completion = EM::Completion.new
        @requeue_options_completion = EM::Completion.new

        @reply_queues = {}

        open_channel(:prefetch => prefetch) do |channel|
          @channel_completion.succeed(channel)
          exchange_type = opts[:fanout] ? :fanout : :direct
          channel.send(exchange_type, @queue_def.normalise, @options.exchange) do |exchange|
            @exchange_completion.succeed(exchange)
          end
        end

        open_channel(:prefetch => prefetch) do |channel|
          extra_opts = {}
          if opts[:fanout]
            if opts[:queue_append]
              queue_name = "#{@queue_def.normalise}.#{opts[:queue_append]}"
            else
              extra_opts[:durable] = false
              extra_opts[:auto_delete] = true
              queue_name = ""
            end
          else
            queue_name = @queue_def.normalise
          end
          channel.queue(queue_name, @options.queue.merge(extra_opts)) do |queue|
            @exchange_completion.completion do |exchange|
              queue.bind(exchange, :routing_key => @queue_def.normalise)
              @queue_completion.succeed(queue)
              @requeue_options_completion.succeed(:exchange => exchange, :queue => queue)
            end
          end
        end

        blk.call(self) if blk
      end

      def ack(multiple=false)
        @channel_completion.completion {|channel| channel.ack(multiple) }
      end

      def setup_reply_queue(reply_queue_name, &blk)
        if @reply_queues[reply_queue_name]
          blk.call(@reply_queues[reply_queue_name])
        else
          @exchange_completion.completion do |exchange|
            logger.debug { "Attaching to reply queue: #{reply_queue_name}" }

            queue_def = QueueDefinition.new(reply_queue_name, :auto_delete => true, :immediate => true, :mandatory => true, :durable => false)

            Smith::Messaging::Sender.new(queue_def) do |sender|
              @reply_queues[reply_queue_name] = sender
              blk.call(sender)
            end
          end
        end
      end

      # Subscribes to a queue and passes the headers and payload into the
      # block. +subscribe+ will automatically acknowledge the message unless
      # the options sets :ack to false.
      def subscribe(handler=nil, &blk)

        blk = handler || blk

        @queue_completion.completion do |queue|
          @requeue_options_completion.completion do |requeue_options|
            if !queue.subscribed?
              opts = @options.subscribe
              logger.debug { "Subscribing to: [queue]:#{@queue_def.denormalise} [options]:#{opts}" }
              queue.subscribe(opts) do |metadata,payload|
                if payload
                  on_message(metadata, payload, requeue_options, &blk)
                else
                  logger.verbose { "Received null message on: #{@queue_def.denormalise} [options]:#{opts}" }
                end
              end
            else
              logger.error { "Queue is already subscribed too. Not listening on: #{@queue_def.denormalise}" }
            end
          end
        end
      end

      def unsubscribe(&blk)
        @queue_completion.completion do |queue|
          queue.unsubscribe(&blk)
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
              else
                blk.call(nil,nil)
              end
            end
          end
        end
      end

      # Define a channel error handler.
      def on_error(chain=false, &blk)
        # TODO Check that this chains callbacks
        @channel_completion.completion do |channel|
          channel.on_error(&blk)
        end
      end

      def on_message(metadata, payload, requeue_options, &blk)
        if @payload_type.empty? || @payload_type.include?(@acl_type_cache.get_by_hash(metadata.type))
          @message_counter.increment_counter
          if metadata.reply_to
            setup_reply_queue(metadata.reply_to) do |queue|
              Foo.new(metadata, payload, @foo_options.merge(:reply_queue => queue), requeue_options, &blk)
            end
          else
            Foo.new(metadata, payload, @foo_options, requeue_options, &blk)
          end
        else
          allowable_acls = @payload_type.join(", ")
          received_acl = @acl_type_cache.get_by_hash(metadata.type)
          raise ACL::IncorrectTypeError, "Received ACL: #{received_acl} on queue: #{@queue_def.denormalise}. This queue can only accept the following ACLs: #{allowable_acls}"
        end
      end

      private :on_message

      def queue_name
        @queue_def.denormalise
      end

      def delete(&blk)
        @exchange_completion.completion do |exchange|
          @queue_completion.completion do |queue|
            @channel_completion.completion do |channel|
              queue.unbind(exchange) do
                queue.delete do
                  exchange.delete do
                    channel.close(&blk)
                  end
                end
              end
            end
          end
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

      def on_requeue_limit(&blk)
        @requeue_options_completion.completion do |requeue_options|
          requeue_options.merge!(:on_requeue_limit => blk)
        end
      end
    end

    class Foo
      include Smith::Logger

      attr_accessor :metadata

      def initialize(metadata, data, opts={}, requeue_opts, &blk)
        @metadata = metadata
        @reply_queue = opts[:reply_queue]
        @requeue_opts = requeue_opts

        @acl_type_cache = AclTypeCache.instance

        @time = Time.now

        # TODO add some better error checking/diagnostics.
        clazz = @acl_type_cache.get_by_hash(metadata.type)

        @message = clazz.new.parse_from_string(data)

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

        if @metadata.reply_to
          @reply_queue.publish((blk) ? blk.call : acl, :correlation_id => @metadata.message_id)
        else
          logger.error { "Cannot reply to a message that has no reply_to: #{@metadata.exchange}." }
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
      alias :call :ack

      # Make #call invoke ack. This makes the following idiom possible:
      #
      # receiver('queue').subscribe do |payload, receiver|
      #   blah(payload, &receiver)
      # end
      #
      # which will ensure that #ack is called properly.
      def to_proc
        proc { |obj| ack(obj) }
      end

      # reject the message. Optionally requeuing it.
      def reject(opts={})
        @metadata.reject(opts)
      end

      # the correlation_id
      def correlation_id
        @metadata.correlation_id
      end
    end
  end
end
