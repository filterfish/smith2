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
            data = case
                   when options[:json_given]
                     options[:json]
                   when options[:file_given]
                     file = Pathname.new(options[:file])
                     if file.exist?
                       file.read
                     else
                       responder.value("File does not exist: #{file.display}")
                     end
                   end

            Smith::Messaging::Sender.new(target.first, :auto_delete => options[:dynamic], :persistent => true, :nowait => false, :strict => true).ready do |sender|

              work = proc do |n,iter|
                sender.publish(json_to_payload(data, options[:type])) do
                  iter.next
                end
              end

              done = proc do
                responder.value
              end

              EM::Iterator.new(0..options[:number] - 1).each(work, done)

            end
          rescue MultiJson::DecodeError => e
            responder.value(e)
            Smith.stop
          end
        end
      end

      private

      def json_to_payload(data, type)
        Smith::ACL::Payload.new(type.to_sym).content do |m|
          MultiJson.load(data, :symbolize_keys => true).each do |k,v|
            m.send("#{k}=".to_sym, v)
          end
        end
      end

      def options_spec
        banner "Send a message to a queue. The ACL can also be specified."

        opt :type,    "message type", :type => :string, :default => 'default', :short => :t
        opt :json,    "supply the json representation with this flag", :type => :string, :conflicts => :file, :short => :j
        opt :file,    "read the data from the named file", :type => :string, :conflicts => :json, :short => :f
        opt :number,  "the number of times to send the message", :type => :integer, :default => 1, :short => :n
        opt :dynamic, "send message to a dynamic queue", :type => :boolean, :default => false, :short => :d
      end
    end
  end
end
