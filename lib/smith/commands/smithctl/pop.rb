# -*- encoding: utf-8 -*-
require 'smith/messaging/queue'

module Smith
  module Commands
    class Pop < CommandBase
      def execute
        pop
      end

      def pop
        case target.size
        when 0
          "No queue specified. Please specify a queue."
        when 1

          queue = target.first

          Messaging::Queue.number_of_messages(queue) do |queue_length|

            # Number of messages on the queue.
            number_to_remove = (options[:number] > queue_length) ? queue_length : options[:number]

            Messaging::Receiver.new(queue, :auto_ack => false, :prefetch => number_to_remove, :passive => true) do |receiver|

              receiver.on_error do |ch,channel_close|
                case channel_close.reply_code
                when 404
                  responder.succeed("Queue does not exist: #{queue}")
                else
                  responder.succeed("Unknown error: #{channel_close.reply_text}")
                end
              end

              worker = proc do |acc, n, iter|
                receiver.pop do |payload,r|
                  if payload
                    acc[:result] << print_message(payload) if options[:print]
                    acc[:count] += 1

                    if n == number_to_remove - 1
                      if options[:remove]
                        r.ack(true)
                      else
                        r.reject(:requeue => true)
                      end
                    end
                  end
                  iter.return(acc)
                end
              end

              finished = proc do |acc|
                logger.debug { "Removing #{acc[:count]} message from #{receiver.queue_name}" }
                responder.succeed(acc[:result].join("\n"))
              end

              EM::Iterator.new(0...number_to_remove).inject({:count => 0, :result => [], :ack => nil}, worker, finished)
            end
          end
        else
          "You can only specify one queue at a time"
        end
      end

      private

      def print_message(message)
        if options[:json]
          message.to_json
        else
          message.inspect
        end
      end

      def options_spec
        banner "Pop messages off the named queue.", "<queue>"

        opt    :print,  "print the message", :short => :p
        opt    :json ,  "return the JSON representation of the message", :short => :j
        opt    :remove, "remove the message from the queue", :short => :r
        opt    :number, "the number of messages to remove", :default =>1,  :short => :n
      end
    end
  end
end
