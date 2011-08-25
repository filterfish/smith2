# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Start < Command
      def execute(target)
        if target.empty?
          "Start what? No agent specified."
        else
          target.each do |agent|
            agents[agent].name = agent
            agents[agent].start
          end
          nil
        end
      end
    end
  end
end
