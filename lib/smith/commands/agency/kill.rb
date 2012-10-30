# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Kill < CommandBase
      def execute
        work = ->(agent_name, iter) do
          agents[agent_name].kill
          iter.next
        end

        done = -> { responder.succeed('') }

        EM::Iterator.new(target).each(work, done)
      end

      private

      def options_spec
        banner "Kill an agent/agents."
      end
    end
  end
end
