#encoding: utf-8

module Smith
  module AgencyCommands
    class List < AgencyCommand
      def execute(target)
        running_agents = agents.state(:running).map(&:name)
        if running_agents.empty?
          logger.info("No agents running.")
        else
          logger.info("Agents running: #{running_agents.sort.join(', ')}.")
        end
      end
    end
  end
end
