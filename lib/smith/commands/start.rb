#encoding: utf-8

module Smith
  module Commands
    class Start < Command
      def execute(target)
        target.each do |agent|
          agents[agent].name = agent
          agents[agent].start
        end
      end
    end
  end
end
