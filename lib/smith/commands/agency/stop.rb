# -*- encoding: utf-8 -*-

require_relative 'common'

module Smith
  module Commands
    class Stop < CommandBase

      include Common

      def execute
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
              # I don't understand why I need to put self here. target= is a method
              # on Command so I would have thought that would be used but a local
              # variable is used instead of the method. TODO work out why and fix.
              self.target = agent_group(options[:group])
              if target.empty?
                responder.value("There are no agents in group: #{options[:group]}")
                return
              end
            rescue RuntimeError => e
              responder.value(e)
              return
            end
          end

          ret = target.inject([]) do |acc,agent_name|
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
