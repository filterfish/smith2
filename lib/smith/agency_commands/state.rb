#encoding: utf-8

module Smith
  module AgencyCommands
    class State < AgencyCommand
      def execute(target)
        target.inject([]) do |acc,agent_name|
          logger.info("Agent state for #{agent_name}: #{agents[agent_name].state}.")
        end
      end
    end
  end
end
