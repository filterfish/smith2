#encoding: utf-8

module Smith
  module Commands
    class Stop < Command
      def execute(target)
        case target.first
        when 'agency'
          running_agents = agents.state(:running)
          if running_agents.empty?
            logger.info("Agency shutting down.")
            Smith.stop
          else
            logger.warn("Agents are still running: #{running_agents.map(&:name).join(", ")}.") unless running_agents.empty?
            logger.info("Agency not shutting down. Use force_stop if you really want to shut it down.")
          end
        when 'all'
          agents.state(:running).each do |agent|
            agent.stop
          end
        else
          target.each do |agent_name|
            if agents[agent_name].running?
              agents[agent_name].stop
            else
              logger.warn("Agent not running: #{agent_name}")
            end
          end
        end
      end
    end
  end
end
