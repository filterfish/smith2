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
          :error_queue => opts.delete(:error_queue) { false },
          :auto_ack => option_or_default(@queue_def.options, :auto_ack, true),
          :threading => option_or_default(@queue_def.options, :threading, false)}

        fanout_options = if opts.delete(:fanout)
          {:persistence => opts.delete(:fanout_persistence) { true }, :queue_suffix => opts.delete(:fanout_queue_suffix)}
        end

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
          exchange_type = (fanout_options) ? :fanout : :direct
          channel.send(exchange_type, @queue_def.normalise, @options.exchange) do |exchange|
            @exchange_completion.succeed(exchange)
          end
        end

        open_channel(:prefetch => prefetch) do |channel|
          channel.queue(*fanout_queue_and_opts(fanout_options)) do |queue|
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

            reply_queue_def = QueueDefinition.new(reply_queue_name, :auto_delete => true, :immediate => true, :mandatory => true, :durable => false)

            Smith::Messaging::Sender.new(reply_queue_def) do |sender|
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
              queue.subscribe(opts) do |metadata, payload|
                if payload
                  on_message(metadata, payload, requeue_options, &blk)
                else
                  logger.debug { "Received null message on: #{@queue_def.denormalise} [options]:#{opts}" }
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

      private

      # Calculates the queue name and the various queue options based on the
      # fanout_options and returns them in a form that can be used by the
      # queue constuctor.
      #
      # @param [Hash] fanout_options the various fanout related options
      #
      # @raise [ArgumentError] raised if :queue_suffix is given without the :persistence flag
      #
      # @return [Array<queue_name, options]
      def fanout_queue_and_opts(fanout_options)
        if fanout_options
          if fanout_options[:persistence]
            if fanout_options[:queue_suffix]
              ["#{@queue_def.normalise}.#{fanout_options[:queue_suffix]}", @options.queue]
            else
              raise ArgumentError, "Incorrect options. :fanout_queue_suffix must be provided if :fanout_persistence is true."
            end
          else
            ["", @options.queue.merge(:durable => false, :auto_delete => true)]
          end
        else
          [@queue_def.normalise, @options.queue]
        end
      end
    end

    # This class gets passed into the receive block and is a representation of
    # both the message and the message metadata. It also handles requeues and
    # retries. In short it's very much a convenience class which is why I have
    # no idea what to call it!
    #
    class Foo
      include Smith::Logger

      attr_accessor :metadata

      def initialize(metadata, data, opts={}, requeue_opts, &blk)
        @opts = opts
        @metadata = metadata
        @reply_queue = @opts[:reply_queue]
        @requeue_opts = requeue_opts

        @acl_type_cache = AclTypeCache.instance

        @time = Time.now

        # TODO add some better error checking/diagnostics.
        clazz = @acl_type_cache.get_by_hash(metadata.type)

        @message = clazz.new.parse_from_string(data)

        if @opts[:threading]
          EM.defer do
            blk.call(@message, self)
            ack if @opts[:auto_ack]
          end
        else
          blk.call(@message, self)
          ack if @opts[:auto_ack]
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

      # Publish the ACL to the error queue set up for this queue. This method is only
      # available if the :error_queue option is set to true. Note this is the
      # receive queue name which in most cases is the same at the sender name
      # but if you are using fanout queues it will be different.
      #
      # @param [ACL] acl Optional ACL. With any options this method will fail the entire
      #                  ACL. This may not be what you want though. So this opton allows
      #                  you to fail another ACL. WARNING: there is no type checking at
      #                  the moment. If you publish an ACL that this agent can't process
      #                  and republish that ACL at a future date the agent will blow up.
      #
      # @param [Hash] opts Options hash. This currently only supports on option:
      #   :ack. If you publish a different ACL from the one received you will have to
      #   ack that message yourself and make sure `:ack => nil`
      #
      # @yieldparam [Fixnum] The number of ACLs on the error queue.
      #
      def fail(acl=nil, opts={:ack => true}, &blk)
        if @opts[:error_queue]
          message = (acl) ? acl : @message
          Sender.new("#{queue_name}.error") do |queue|
            logger.debug { "Republishing ACL to error queue: \"#{queue.queue_name}\"" }
            queue.publish(message) do
              queue.number_of_messages do |count|
                @metadata.ack if opts[:ack]
                blk && blk && blk.call(count + 1)
              end
            end
          end
        else
          raise ArgumentError, "You cannot fail this queue as you haven't specified the :error_queue option"
        end
      end

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

      # Return the queue_name. Note this is the receive queue name which in
      # most cases is the same at the sender name but if you are using fanout
      # queues it will be different.
      #
      # @return [String] the name of the queue
      #
      def queue_name
        @a561facf ||= begin
                        queue_name = @metadata.channel.queues.keys.detect { |q| q == @metadata.exchange }
                        if queue_name
                          @a561facf = remove_namespace(queue_name)
                        else
                          raise UnknownQueue, "Queue not found. You are probably you are using fanout queues: #{remove_namespace(@metadata.exchange)}"
                        end
                      end
      end

      # Remove the Smith namespace prefix (the default is `smith.`)
      #
      # @param [String] queue_name The name of the queue
      #
      # @param [String] The name of the queue with the namespace prefix.
      #
      def remove_namespace(queue_name)
        queue_name.gsub(/^#{Smith.config.smith.namespace}\./, '')
      end
    end
  end
end
