# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Metadata < CommandBase
      def execute
        responder.succeed(target.inject([]) { |acc,agent_name| acc.tap { |a| a << ["#{agent_name}: #{agents[agent_name].metadata}"] } }.join("\n"))
      end

      private

      def options_spec
        banner "Display an agent/agents metadata.", "<uuid>"
      end
    end
  end
end
