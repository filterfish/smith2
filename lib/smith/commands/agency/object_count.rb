# -*- encoding: utf-8 -*-

module Smith
  module Commands
    class ObjectCount < CommandBase
      def execute
        responder.value do
          target.each do |agent|
            if agents[agent].running?
              send_agent_control_message(agents[agent], :command => 'object_count', :options => [options[:threshold].to_s])
            end
          end
          nil
        end
      end

      private

      def send_agent_control_message(agent, message)
        Messaging::Sender.new(agent.control_queue_name, :durable => false, :auto_delete => true, :persistent => true,  :strict => true).ready do |sender|
          sender.publish(ACL::Payload.new(:agent_command).content(message))
        end
      end

      def options_spec
        banner "Dump the ruby ObjectSpace stats. This is purely for debuging purposes only."

        opt    :threshold, "only print objects that have a count greater than the threshold", :type => :integer, :default => 100, :short => :t
      end
    end
  end
end
