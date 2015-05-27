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
            logger.info { "Agency not shutting down. Use --force if you really want to shut it down." }
            blk.call("Not shutting down, agents are still running: #{running_agents.map(&:name).join(", ")}.")
          end
        end
      end

      def stop_all(&blk)
        agents.state(:running).each do |agent|
          agent.stop
        end
        blk.call('')
      end

      def stop_agent(&blk)

        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        #!!!!!!!!!!!! See note about target at end of this file !!!!!!!!!!!!!!
        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        # Sort out any groups. If the group option is set it will override
        # any other specified agents.
        if options[:group]
          begin
            agents_to_stop = agents.find_by_name(agent_group(options[:group])).map(&:uuid)
            if agents_to_stop.empty?
              blk.call("There are no agents in group: #{options[:group]}")
            end
          rescue RuntimeError => e
            return blk.call(e.message)
          end
        else
          if options[:name]
            agents_to_stop = agents.find_by_name(options[:name]).map(&:uuid)
          else
            agents_to_stop = target
          end
        end

        errors = agents_to_stop.inject([]) { |acc,uuid| acc << stop_if_running(uuid) }
        blk.call(format_error_message(errors))
      end

      def stop_if_running(uuid)
        agent = agents[uuid]
        if agent
          if agent.running?
            agent.stop
            nil
          end
        else
          logger.warn { "Agent does not exist: #{uuid}" }
          uuid
        end
      end

      def format_error_message(errors)
        errors = errors.compact
        case errors.size
        when 0
          ''
        when 1
          "Agent does not exist: #{errors.first}"
        else
          "Agents do not exist: #{errors.join(", ")}"
        end
      end

      def options_spec
        banner "Stop an agent/agents.", "<uuid[s]>"

        opt    :group, "Stop everything in the specified group", :type => :string, :short => :g
        opt    :name,  "Stop an agent(s) by name", :type => :string, :short => :n
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
