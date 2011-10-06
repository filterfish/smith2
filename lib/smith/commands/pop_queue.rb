# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class PopQueue < Command
      def execute
        case target.size
        when 0
          responder.value("Remove what? No queue specified.")
        when 1
          Messaging::Receiver.new(target.shift).ready do |receiver|
            callback = proc do
              receiver.pop do |metadata,payload|
                if !options[:remove]
                  metadata.reject(:requeue => true)
                end
                responder.value(payload)
              end
            end

            errback = proc { responder.value}

            receiver.messages?(callback, errback)
          end
        else
          responder.value("You can only specifiy one queue at a time")
        end
      end

      def options_parser
        Trollop::Parser.new do
          banner  Command.banner('pop-queue')
          opt     :remove, "remove the message from the queue", :short => :r
        end
      end
    end
  end
end
