# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class State < Command
      def execute
        responder.value do
          target.inject([]) do |acc,agent_name|
            acc.tap { |a| a << ["#{agent_name}: #{agents[agent_name].state}"] }
          end.join("\n")
        end
      end
    end
  end
end
