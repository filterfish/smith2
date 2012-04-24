# -*- encoding: utf-8 -*-
require 'yajl'

module Smith
  module Commands
    class Pop < CommandBase
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
                        acc << print_message(r.payload)
                      end
                    end
                  else
                    result.inject([]) do |a,r|
                      a.tap do |acc|
                        r.reject(:requeue => true)
                        acc << print_message(r.payload)
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

      private

      def print_message(message)
        if options[:print]
          if options[:json]
            message.as_json
          else
            message.inspect
          end
        end
      end

      def options_spec
        banner "Pop messages off the named queue."

        opt    :print,  "print the message", :short => :p
        opt    :json ,  "return the JSON representation of the message", :short => :j
        opt    :remove, "remove the message from the queue", :short => :r
        opt    :number, "the number of messages to remove", :default =>1,  :short => :n
      end
    end
  end
end
