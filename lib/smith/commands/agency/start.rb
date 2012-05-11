# -*- encoding: utf-8 -*-

require_relative '../common'

module Smith
  module Commands
    class Start < CommandBase

      include Common

      def execute

        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        #!!!!!!!!!!!! See not about target at end of this file !!!!!!!!!!!!!!
        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        # Sort out any groups. If the group option is set it will override
        # any other specified agents.
        if options[:group]
          begin
            agents_to_start = agent_group(options[:group])
            if agents_to_start.empty?
              responder.value("There are no agents in group: #{options[:group]}")
              return
            end
          rescue RuntimeError => e
            responder.value(e.message)
            return
          end
        else
          agents_to_start = target
        end

        responder.value do
          if agents_to_start.empty?
            "Start what? No agent specified."
          else
            agents_to_start.map do |agent|
              agents[agent].name = agent
              if agents[agent].path
                if options[:kill]
                  agents[agent].kill
                end
                agents[agent].start
                nil
              else
                "Unknown agent: #{agents[agent].name}".tap do |m|
                  logger.error { m }
                end
              end
            end.compact.join("\n")
          end
        end
      end

      private

      def options_spec
        banner "Start an agent/agents or group of agents."

        opt    :kill,  "Reset the state of the agent before starting", :short => :k
        opt    :group, "Start everything in the specified group", :type => :string, :short => :g
      end
    end
  end
end


# A note about target.
#
# Target is a method and if you assign something to it strange things happen --
# even if the code doesn't get run! I'm not strictly sure what's going on but I
# think it's something to do with the a variable aliasing a method of the same
# name. So even though the code isn't being run it gets compiled and that
# somehow aliases the method. This looks like a bug in yarv to me.
