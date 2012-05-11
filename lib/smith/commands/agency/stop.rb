# -*- encoding: utf-8 -*-

require_relative '../common'

module Smith
  module Commands
    class Stop < CommandBase

      include Common

      def execute

        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        #!!!!!!!!!!!! See not about target at end of this file !!!!!!!!!!!!!!
        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        case target.first
        when 'agency'
          running_agents = agents.state(:running)
          if running_agents.empty?
            logger.info { "Agency shutting down." }
            Smith.stop
            responder.value
          else
            logger.warn { "Agents are still running: #{running_agents.map(&:name).join(", ")}." }
            logger.info { "Agency not shutting down. Use force_stop if you really want to shut it down." }
            responder.value("Not shutting down, agents are still running: #{running_agents.map(&:name).join(", ")}.")
          end
        when 'all'
          agents.state(:running).each do |agent|
            agent.stop
          end
          responder.value
        else
          # Sort out any groups. If the group option is set it will override
          # any other specified agents.
          if options[:group]
            begin
              agents_to_stop = agent_group(options[:group])
              if agents_to_stop.empty?
                responder.value("There are no agents in group: #{options[:group]}")
                return
              end
            rescue RuntimeError => e
              responder.value(e)
              return
            end
          else
            agents_to_stop = target
          end

          ret = agents_to_stop.inject([]) do |acc,agent_name|
            acc << if agents[agent_name].running?
                     agents[agent_name].stop
                     nil
                   else
                     logger.warn { "Agent not running: #{agent_name}" }
                     agent_name
                   end
          end
          responder.value((ret.compact.empty?) ? nil : "Agent(s) not running: #{ret.compact.join(", ")}")
        end
      end

      private

      def options_spec
        banner "Stop an agent/agents."

        opt    :group, "Stop everything in the specified group", :type => :string, :short => :g
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
