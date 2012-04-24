# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Metadata < CommandBase
      def execute
        responder.value do
          target.inject([]) do |acc,agent_name|
            acc.tap { |a| a << ["#{agent_name}: #{agents[agent_name].metadata}"] }
          end.join("\n")
        end
      end

      private

      def options_spec
        banner "Display an agent/agents metadata."
      end
    end
  end
end
