# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Rm < CommandBase
      def execute
        case target.size
        when 0
          responder.value("No queue specified. Please specify a queue.")
        else
          Smith.on_error do |ch,channel_close|
            case channel_close.reply_code
            when 404
              responder.value("No such queue: #{extract_queue(channel_close.reply_text)}")
            when 406
              responder.value("Queue not empty: #{extract_queue(channel_close.reply_text)}. Use -f to force remove")
            else
              responder.value("Unknown error: #{channel_close.reply_text}")
            end
          end

          target.each do |queue_name|
            Smith.channel.queue("smith.#{queue_name}", :passive => true) do |queue|
              queue_options = (options[:force]) ? {} : {:if_unused => true, :if_empty => true}
              queue.delete(queue_options) do |delete_ok|
                responder.value((options[:verbose]) ? delete_ok.message_count.to_s : nil)
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
