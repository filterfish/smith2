# -*- encoding: utf-8 -*-

module Smith
  module Commands
    class ObjectCount < CommandBase
      def execute
        if target.size > 1
          responder.succeed("You can only specify one agent at at time.")
        else
          object_count(target.first) do |objects|
            responder.succeed(objects)
          end
        end
      end

      def object_count(agent, &blk)
        if agents[agent].running?
          Messaging::Sender.new(agent.control_queue_name, :durable => false, :auto_delete => true, :persistent => true,  :strict => true) do |sender|
            sender.on_reply(blk)
            sender.publish(ACL::Payload.new(:agent_command, :command => 'object_count', :options => [options[:threshold].to_s]))
          end
        end
      end

      private

      def options_spec
        banner "Dump the ruby ObjectSpace stats. This is purely for debuging purposes only."

        opt    :threshold, "only print objects that have a count greater than the threshold", :type => :integer, :default => 100, :short => :t
      end
    end
  end
end
