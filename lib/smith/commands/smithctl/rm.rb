# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Rm < CommandBase
      def execute
        case target.size
        when 0
          responder.succeed("No queue specified. Please specify a queue.")
        else
          @on_error = proc do |ch,channel_close|
            case channel_close.reply_code
            when 404
              responder.succeed("No such queue: [#{channel_close.reply_code}]: #{channel_close.reply_text}")
            when 406
              responder.succeed("Queue not empty: [#{channel_close.reply_code}]: #{channel_close.reply_text}.")
            else
              responder.succeed("Unknown error: [#{channel_close.reply_code}]: #{channel_close.reply_text}")
            end
          end

          target.each do |queue_name|
            delete_queue(queue_name) do |delete_ok|
              delete_exchange(queue_name) do |delete_ok|
                responder.succeed((options[:verbose]) ? delete_ok.message_count.to_s : nil)
              end
            end
          end
        end
      end

      private

      def options_spec
        banner "Display or remove a message from the named queue."

        opt    :force,   "force the removal even if there are messages on the queue", :short => :f
        opt    :verbose, "print the number of messages deleted", :short => :v
      end

      def delete_exchange(exchange_name, &blk)
        AMQP::Channel.new(Smith.connection) do |channel,ok|
          channel.on_error(&@on_error)
          channel.direct("smith.#{exchange_name}", :passive => true) do |exchange|
            exchange_options = (options[:force]) ? {} : {:if_unused => true}
            exchange.delete(exchange_options) do |delete_ok|
              blk.call(delete_ok)
            end
          end
        end
      end

      def delete_queue(queue_name, &blk)
        AMQP::Channel.new(Smith.connection) do |channel,ok|
          channel.on_error(&@on_error)
          channel.queue("smith.#{queue_name}", :passive => true) do |queue|
            queue_options = (options[:force]) ? {} : {:if_unused => true, :if_empty => true}
            queue.delete(queue_options) do |delete_ok|
              blk.call(delete_ok)
            end
          end
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
