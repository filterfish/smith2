# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Kill < CommandBase
      def execute
        target.each do |agent_name|
          agents[agent_name].kill
        end
        responder.value
      end

      private

      def options_spec
        banner "Kill an agent/agents."
      end
    end
  end
end
