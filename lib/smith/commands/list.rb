# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class List < Command
      def execute(target)
        running_agents = agents.state(:running).map(&:name)
        if running_agents.empty?
          "No agents running."
        else
          "Agents running: #{running_agents.sort.join(', ')}."
        end
      end
    end
  end
end
