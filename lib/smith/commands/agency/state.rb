# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class State < CommandBase
      def execute
        responder.value do
          target.inject([]) do |acc,agent_name|
            acc.tap { |a| a << ["#{agent_name}: #{agents[agent_name].state}"] }
          end.join("\n")
        end
      end

      private

      def options_spec
        banner "Show the state of an agent/agents - deprecated."
      end
    end
  end
end
