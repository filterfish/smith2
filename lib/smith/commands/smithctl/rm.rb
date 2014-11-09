# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Rm < CommandBase
      def execute
        case target.size
        when 0
          responder.succeed("No queue specified. Please specify a queue.")
        else
          worker = ->(queue_name, iter) do
            delete_queue(queue_name) do |delete_ok|
              delete_exchange(queue_name, &iter)
            end
          end

          # FIXME: Return errors to the caller rather than doing nothing or logging errors
          done = -> { responder.succeed }

          EM::Iterator.new(target).each(worker, done)
        end
      end

      private

      def options_spec
        banner "Display or remove a message from the named queue."

        opt :force,         "force the removal even if there are messages on the queue", :short => :f
        opt :ignore_errors, "ignore any errors.", :default => false
        opt :log_errors,  "print any errors messages.", :default => false
      end

      # Delete an exchange.
      #
      # @param name [String] name of the exchange.
      # @yield calls the block when the exchange has been deleted
      # @yieldparam [AMQ::Protocol::Channel::Close] the amqp close message
      # FIXME: remove duplication
      def delete_exchange(name, &blk)
        AMQP::Channel.new(Smith.connection) do |channel, ok|

          channel.on_error do |channel, channel_close|
            handler = (options[:ignore_errors]) ? blk : nil
            log_error(channel, channel_close, &handler)
          end

          channel.direct("smith.#{name}", :passive => true) do |exchange|
            exchange_options = (options[:force]) ? {} : {:if_unused => true}
            exchange.delete(exchange_options) do |delete_ok|
              blk.call(delete_ok)
            end
          end
        end
      end

      # Delete an queue.
      #
      # @param name [String] name of the queue.
      # @yield calls the block when the queue has been deleted
      # @yieldparam [AMQ::Protocol::Channel::Close] the amqp close message
      # FIXME: remove duplication
      def delete_queue(queue_name, &blk)
        AMQP::Channel.new(Smith.connection) do |channel, ok|
          channel.on_error do |channel, channel_close|
            handler = (options[:ignore_errors]) ? blk : nil
            log_error(channel, channel_close, &handler)
          end

          channel.queue("smith.#{queue_name}", :passive => true) do |queue|
            queue_options = (options[:force]) ? {} : {:if_unused => true, :if_empty => true}
            queue.delete(queue_options) do |delete_ok|
              blk.call(delete_ok)
            end
          end
        end
      end

      # Get's called when there is a channel error.
      #
      # @param channel [AMQP::Channel] the channel that errored
      # @param channel_close [AMQ::Protocol::Channel::Close] the amqp close message
      #        which contains details of why the channel was claosed.
      def log_error(channel, channel_close, &blk)
        base_error_msg = "#{channel_close.reply_code}, #{channel_close.reply_text}."
        if blk
          logger.error { "#{base_error_msg}. Ignoring as requested" } if options[:log_errors]
          blk.call
        else
          responder.succeed(base_error_msg)
        end
      end

      def extract_queue(message)
        match = /.*?'(.*?)'.*$/.match(message) #[1]
        if match && match[1]
          match[1].sub(/smith\./, '')
        else
          message
        end
      end
    end
  end
end
