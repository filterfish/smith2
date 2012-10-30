# -*- encoding: utf-8 -*-

require 'multi_json'

module Smith
  module Commands
    class Push < CommandBase
      def execute
        push do |ret|
          responder.succeed(ret)
        end
      end

      private

      def push(&blk)
        if target.size == 0
          blk.call("No queue specified. Please specify a queue.")
        else
          begin
            Messaging::Sender.new(target.first, :auto_delete => options[:dynamic], :persistent => true, :nowait => false, :strict => true) do |sender|
              on_work = ->(message, iter) do
                sender.publish(json_to_payload(message, options[:type])) do
                  iter.next
                end
              end

              on_done = -> { blk.call("") }

              iterator.each(on_work, on_done)
            end
          rescue MultiJson::DecodeError => e
            blk.call(e)
          end
        end
      end

      # Return a interator that can iterate over whatever the input is.
      def iterator
        case
        when options[:message_given]
          if options[:number_given]
            EM::Iterator.new([options[:message]] * options[:number])
          else
            EM::Iterator.new([options[:message]])
          end
        when options[:file_given]
          FileReader.new(options[:file])
        else
          raise ArgumentError, "--number option cannot be used when reading messages from standard in." if options[:number_given]
          FileReader.new(STDIN)
        end
      end

      def json_to_payload(data, type)
        ACL::Factory.create(type, MultiJson.load(data, :symbolize_keys => true))
      end

      def options_spec
        banner "Send a message to a queue. The ACL can also be specified."

        opt :type,    "message type", :type => :string, :default => 'default', :short => :t
        opt :message, "the message, as json", :type => :string, :conflicts => :file, :short => :m
        opt :file,    "read messages from the named file", :type => :string, :conflicts => :message, :short => :f
        opt :number,  "the number of times to send the message", :type => :integer, :default => 1, :short => :n
        opt :dynamic, "send message to a dynamic queue", :type => :boolean, :default => false, :short => :d
      end

      class FileReader
        def initialize(file)
          @file = (file.is_a?(IO)) ? file : File.open(file)
        end

        def each(on_work, on_completed)
          on_done = proc do |message|
            line = @file.readline rescue nil
            if line
              class << on_done; alias :next :call; end
              on_work.call(line, on_done)
            else
              on_completed.call
            end
          end

          EM.next_tick(&on_done)
        end
      end
    end
  end
end
