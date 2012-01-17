# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class PopQueue < Command
      def execute
        case target.size
        when 0
          responder.value("No queue specified. Please specify a queue.")
        when 1
          Messaging::Receiver.new(target.shift, :auto_ack => false).ready do |receiver|
            callback = proc do
              receiver.pop do |r|
                if options[:remove]
                  logger.info("Removing message: #{r.metadata.delivery_tag}")
                  r.ack
                else
                  logger.info("Requeuing message: #{r.metadata.delivery_tag}")
                  r.reject(:requeue => true)
                end
                responder.value(r.payload.to_s.strip)
              end
            end

            errback = proc {responder.value(nil)}

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
