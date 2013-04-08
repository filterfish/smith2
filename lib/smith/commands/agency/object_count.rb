# -*- encoding: utf-8 -*-

# FIXME. This needs to be either fixed up or removed. It dumps the output into
# the log at the moment which isn't the place for it. It should also be a
# smithctl command rather than an agency command.

module Smith
  module Commands
    class ObjectCount < CommandBase
      def execute
        if target.size > 1
          responder.succeed("You can only specify one agent at at time.")
        else
          agent = agents[target.first]
          if agent.running?

            # object_count(agent) do |objects|
            #   responder.succeed(objects)
            # end

            object_count(agent)
            responder.succeed('') #(objects)
          else
            responder.succeed("Agent not running: #{target.first}")
          end
        end
      end

      def object_count(agent) #, &blk)
        Messaging::Sender.new(agent.control_queue_def) do |sender|
          # sender.on_reply(blk)
          sender.publish(ACL::AgentCommand.new(:command => 'object_count', :options => [options[:threshold].to_s]))
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
