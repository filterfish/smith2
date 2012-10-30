# -*- encoding: utf-8 -*-

require_relative '../common'

module Smith
  module Commands
    class Stop < CommandBase

      include Common

      def execute
        if target.first == 'agency' || target.first == 'all'
          send("stop_#{target.first}") { |ret| responder.succeed(ret) }
        else
          stop_agent { |ret| responder.succeed(ret) }
        end
      end

      private

      def stop_agency(&blk)
        running_agents = agents.state(:running)
        if running_agents.empty?
          logger.info { "Agency shutting down." }
           blk.call('')
          Smith.stop
        else
          if options[:force]
            blk.call('')
            Smith.stop
          else
            logger.warn { "Agents are still running: #{running_agents.map(&:name).join(", ")}." }
            logger.info { "Agency not shutting down. Use force_stop if you really want to shut it down." }
            blk.call("Not shutting down, agents are still running: #{running_agents.map(&:name).join(", ")}.")
          end
        end
      end

      def stop_all(&blk)
        agents.state(:running).each do |agent|
          agent.stop
          blk.call('')
        end
      end

      def stop_agent(&blk)

        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        #!!!!!!!!!!!! See note about target at end of this file !!!!!!!!!!!!!!
        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        # Sort out any groups. If the group option is set it will override
        # any other specified agents.
        if options[:group]
          begin
            agents_to_stop = agent_group(options[:group])
            if agents_to_stop.empty?
              blk.call("There are no agents in group: #{options[:group]}")
            end
          rescue RuntimeError => e
            return blk.call(e.message)
          end
        else
          agents_to_stop = target
        end

        ret = agents_to_stop.inject([]) do |acc,agent_name|
          acc << stop_if_running(agents[agent_name])
        end
        blk.call((ret.compact.empty?) ? '' : "Agent(s) not running: #{ret.compact.join(", ")}")
      end

      def stop_if_running(agent)
        if agent.running?
          agent.stop
        else
          logger.warn { "Agent not running: #{agent.name}" }
          agent.name
        end
      end

      def options_spec
        banner "Stop an agent/agents."

        opt    :group, "Stop everything in the specified group", :type => :string, :short => :g
        opt    :force, "If stopping the agency and there are agents running stop anyway"
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
