# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Receiver < Endpoint

      include Logger

      def initialize(queue_name, queue_opts={})
        set_receiver_options
        super
      end

      def queue_name
        denormalise(@queue.name)
      end

      # Subscribes to a queue and passes the headers and payload into the
      # block. +subscribe+ will automatically acknowledge the message unless
      # the options sets :ack to false.
      def subscribe(opts={}, &block)
        if !@queue.subscribed?
          options = @normal_subscribe_options.merge(opts)
          logger.debug("Subscribed to: #{queue.name}")
          @queue.subscribe(options) do |metadata,payload|
            reply_payload = nil
            if payload
              decoded_payload = Payload.decode(payload, metadata.type)
              logger.verbose("Received message on: #{@queue.name} #{options}: #{decoded_payload.inspect}")
              block.call(metadata, decoded_payload)
              metadata.ack if options[:ack]
            else
              logger.verbose("Received null message on: #{@queue}")
            end
          end
        else
          logger.error("Queue is already subscribed too. Not listening on: #{queue_name}")
        end
      end

      # Subscribes to a queue, passing the headers and payload into the block,
      # and publishes the result of the block to the reply_to queue.
      # +subscribe_and_reply+ will automatically acknowledge the message unless
      # the options sets :ack to false.
      def subscribe_and_reply(opts={}, &block)
        reply_payload = subscribe(@receive_subscribe_options.merge(opts)) do |metadata,payload|
          if metadata.reply_to
            options = @receive_publish_options.merge(:routing_key => normalise(metadata.reply_to), :correlation_id => metadata.message_id).merge(opts)
            responder = proc do |return_value|
              Sender.new(metadata.reply_to).ready do |sender|
                sender.publish(Payload.new(:default).content(return_value), options)
              end
            end
          else
            # Null responder. If a call on the responder is made log a warning. Something is wrong.
            responder = proc do |return_value|
              logger.error("You are responding to a message that has no reply_to on queue: #{@queue.name}.")
              logger.verbose("Queue options: #{metadata.exchange}.")
            end
          end
          block.call(metadata, payload, Responder.new(responder))
        end
      end

      # pops a message off the queue and passes the headers and payload
      # into the block. +pop+ will automatically acknowledge the message
      # unless the options sets :ack to false.
      # TODO there needs to be an option here that allows ack to be turned
      # on but this method not actually run the ack. This is needed so that
      # the pop-queue command can get a message of the queue without actually
      # consuming it. This is mightly helpfull for your local BOFH.
      def pop(opts={}, &block)
        @queue.pop(@normal_pop_options.merge(opts)) do |metadata, payload|
          if payload
            block.call(metadata, Payload.decode(payload, metadata.type))
            metadata.ack
          end
        end
      end

      private

      def set_receiver_options
        @normal_pop_options = Smith.config.amqp.pop._child
        @normal_subscribe_options = Smith.config.amqp.subscribe._child
        @receive_pop_options = Smith.config.amqp.pop._child.merge(:immediate => true, :mandatory => true)
        @receive_subscribe_options = Smith.config.amqp.subscribe._child.merge(:immediate => true, :mandatory => true)

        # We need the publish opts as weel.
        @normal_publish_options = Smith.config.amqp.publish._child
        @receive_publish_options = Smith.config.amqp.publish._child.merge(:exclusive => true, :immediate => true, :mandatory => true)
      end

      # Class that gets passed into and subscribe_and_reply blocks
      # and allows the block to call the responder using either a
      # block or value. It should make for a cleaner API.
      class Responder
        def initialize(responder=nil)
          @responders = []
          @responders << responder if responder
        end

        def add(responder)
          @responders.insert(0, responder)
        end

        def value(value=nil, &blk)
          value ||= ((blk) ? blk.call : nil)
          @responders.each {|responder| responder.call(value) }
        end
      end
    end
  end
end
