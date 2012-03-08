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
              work = proc do |n,iter|
                receiver.pop do |r|
                  iter.return(r)
                end
              end

              finished = proc do |result|
                responder.value do
                  if options[:remove]
                    logger.debug { "Removing #{result.size} message from #{result.first.queue_name}" }
                    result.inject([]) do |a,r|
                      a.tap do |acc|
                        r.ack
                        acc << {r.metadata.delivery_tag => r.payload}.inspect if options[:print]
                      end
                    end
                  else
                    result.inject([]) do |a,r|
                      a.tap do |acc|
                        r.reject(:requeue => true)
                        acc << {r.metadata.delivery_tag => r.payload}.inspect if options[:print]
                      end
                    end
                  end.join("\n")
                end
              end

              EM::Iterator.new(0..options[:number] - 1).map(work, finished)
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
          opt     :print,   "print the message", :short => :p
          opt     :remove,  "remove the message from the queue", :short => :r
          opt     :number,  "the number of messages to remove", :default =>1,  :short => :n
        end
      end
    end
  end
end
