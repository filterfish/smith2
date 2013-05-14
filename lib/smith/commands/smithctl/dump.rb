# -*- encoding: utf-8 -*-
require 'multi_json'
require 'smith/messaging/queue'

module Smith
  module Commands
    class Dump < CommandBase
      def execute
        MultiJson.use(:oj)
        dump
      end

      def dump
        case target.size
        when 0
          "No queue specified. Please specify a queue."
        when 1
          queue = target.first
          Messaging::Queue.number_of_messages(queue) do |queue_length|
            Messaging::Receiver.new(queue, :auto_ack => false, :prefetch => 1000, :passive => true) do |receiver|

              count = 0
              t_start = Time.now.to_f

              receiver.on_error do |ch,channel_close|
                raise
                case channel_close.reply_code
                when 404
                  responder.succeed("Queue does not exist: #{queue}")
                else
                  responder.succeed("Unknown error: #{channel_close.reply_text}")
                end
                Smith.stop
              end

              if queue_length > 0
                EM.add_periodic_timer(1) do
                  Messaging::Queue.number_of_messages(queue) do |queue_length|
                    if queue_length == 0
                      t_end = Time.now.to_f
                      if options[:verbose]
                        responder.succeed("dumped #{count} messages in #{t_end - t_start} seconds.")
                      else
                        responder.succeed("")
                      end
                    end
                  end
                end

                receiver.subscribe do |payload, r|
                  if payload
                    EM.next_tick do
                      STDOUT.puts MultiJson.dump(payload)
                    end
                  end
                  count += 1
                  r.ack(true)
                end
              else
                responder.succeed("No messages on queue: #{queue}")
              end
            end
          end
        else
          "You can only specify one queue at a time"
        end
      end

      private

      def options_spec
        banner "Dump a queue to STDOUT.\n\n  This is a very DANGEROUS command in that it removes all messages from a queue."

        opt    :'yes-i-want-to-remove-all-messaeges-from-the-queue',  "Remove all messages from the queue and print to stdout", :type => :boolean,  :short => :none
        opt    :verbose,                                              "print the number of messages backed up.", :type => :boolean,  :short => :v
      end
    end
  end
end
