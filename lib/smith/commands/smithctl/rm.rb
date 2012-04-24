# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Rm < CommandBase
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

      private

      def options_spec
        banner "Display or remove a message from the named queue."

        opt    :force,   "force the removal even if there are messages on the queue", :short => :f
        opt    :verbose, "print the number of messages deleted", :short => :v
      end
    end
  end
end
