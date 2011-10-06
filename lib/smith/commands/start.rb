# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Start < Command
      def execute
        if target.empty?
          "Start what? No agent specified."
        else
          responder.value do
            target.map do |agent|
              agents[agent].name = agent
              if agents[agent].path
                agents[agent].start
                nil
              else
                "Unknown agent: #{agents[agent].name}".tap do |m|
                  logger.error(m)
                end
              end
            end.compact.join("\n")
          end
        end
      end
    end
  end
end
