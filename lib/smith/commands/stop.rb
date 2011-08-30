# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Stop < Command
      def execute
        case target.first
        when 'agency'
          running_agents = agents.state(:running)
          if running_agents.empty?
            logger.info("Agency shutting down.")
            Smith.stop
            nil
          else
            logger.warn("Agents are still running: #{running_agents.map(&:name).join(", ")}.") unless running_agents.empty?
            logger.info("Agency not shutting down. Use force_stop if you really want to shut it down.")
            "Not shutting down, agents are still running: #{running_agents.map(&:name).join(", ")}."
          end
        when 'all'
          agents.state(:running).each do |agent|
            agent.stop
          end
          nil
        else
          ret = target.inject([]) do |acc,agent_name|
            acc << if agents[agent_name].running?
              agents[agent_name].stop
              nil
            else
              logger.warn("Agent not running: #{agent_name}")
              agent_name
            end
          end
          (ret.compact.empty?) ? nil : "Agent(s) not running: #{ret.compact.join(", ")}"
        end
      end
    end
  end
end
