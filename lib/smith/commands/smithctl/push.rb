# -*- encoding: utf-8 -*-

require 'multi_json'

module Smith
  module Commands
    class Push < CommandBase
      def execute
        if target.size == 0
          responder.value("No queue specified. Please specify a queue.")
          Smith.stop(true)
        else
          begin
            messages = case
                   when options[:message_given]
                     options[:message]
                   when options[:file_given]
                     responder.value("--number option cannot be used with the --file option.") if options[:number_given]

                     file = Pathname.new(options[:file])
                     if file.exist?
                       file.read
                     else
                       responder.value("File does not exist: #{file.display}")
                     end
                   else
                     responder.value("--number option cannot be used when reading messages from standard in.") if options[:number_given]
                     STDIN.read
                   end

            if messages.nil? || messages && messages.empty?
              responder.value("Message must be empty.")
            end

            # This is starting to get a bit messy. The iterator is being used
            # for two purposes: the first is to send multiple messages, the
            # second is send the same message multiple times.
            # TODO Clean this up.

            Messaging::Sender.new(target.first, :auto_delete => options[:dynamic], :persistent => true, :nowait => false, :strict => true).ready do |sender|
              work = proc do |message,iter|
                m = (options[:number_given]) ? messages : message

                sender.publish(json_to_payload(m, options[:type])) do
                  iter.next
                end
              end

              done = proc do
                responder.value
              end

              data = (options[:number_given]) ? 0..options[:number] - 1 : messages.split("\n")

              EM::Iterator.new(data).each(work, done)
            end
          rescue MultiJson::DecodeError => e
            responder.value(e)
            Smith.stop
          end
        end
      end

      private

      def json_to_payload(data, type)
        ACL::Payload.new(type.to_sym).content do |m|
          MultiJson.load(data, :symbolize_keys => true).each do |k,v|
            m.send("#{k}=".to_sym, v)
          end
        end
      end

      def options_spec
        banner "Send a message to a queue. The ACL can also be specified."

        opt :type,    "message type", :type => :string, :default => 'default', :short => :t
        opt :message, "the message, as json", :type => :string, :conflicts => :file, :short => :m
        opt :file,    "read the data from the named file. One message per line", :type => :string, :conflicts => :message, :short => :f
        opt :number,  "the number of times to send the message", :type => :integer, :default => 1, :short => :n, :conflicts => :file
        opt :dynamic, "send message to a dynamic queue", :type => :boolean, :default => false, :short => :d
      end
    end
  end
end
