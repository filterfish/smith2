# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Metadata < Command
      def execute
        responder.value do
          target.inject([]) do |acc,agent_name|
            acc.tap { |a| a << ["#{agent_name}: #{agents[agent_name].metadata}"] }
          end.join("\n")
        end
      end
    end
  end
end
