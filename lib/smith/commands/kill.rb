# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Kill < Command
      def execute
        target.each do |agent_name|
          agents[agent_name].kill
        end
        nil
      end
    end
  end
end
