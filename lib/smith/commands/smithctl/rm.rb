# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Rm < Command
      def execute
        case target.size
        when 0
          responder.value("No queue specified. Please specify a queue.")
        else
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

      def options_parser
        Trollop::Parser.new do
          banner  Command.banner('remove-queue')
          opt     :force,   "force the removal even if there are messages on the queue", :short => :f
          opt     :verbose, "print the number of messages deleted", :short => :v
        end
      end

      def format_output(message_count)
        if options[:verbose]
          responder.value("Queue deleted. #{message_count}s messages deleted.")
        end
      end
    end
  end
end
