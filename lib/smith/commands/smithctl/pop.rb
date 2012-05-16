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
              work = proc do |acc,n,iter|
                receiver.pop do |r|
                  if options[:remove]
                    r.ack
                  else
                    r.reject(:requeue => true)
                  end

                  acc[:result] << print_message(r.payload) if options[:print]
                  acc[:count] += 1

                  iter.return(acc)
                end
              end

              finished = proc do |acc|
                responder.value do
                  logger.debug { "Removing #{acc[:count]} message from #{receiver.queue_name}" }
                  acc[:result].join("\n")
                end
              end

              EM::Iterator.new(0..options[:number] - 1).inject({:count => 0, :result => []}, work, finished)
            end

            errback = proc {responder.value(nil)}

            receiver.messages?(callback, errback)
          end
        else
          responder.value("You can only specify one queue at a time")
        end
      end

      private

      def print_message(message)
        if options[:json]
          message.as_json
        else
          message.inspect
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
