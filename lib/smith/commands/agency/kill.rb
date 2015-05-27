# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Kill < CommandBase
      def execute
        work = ->(acc, uuid, iter) do
          if agents.exist?(uuid)
            agents[uuid].kill
          else
            acc << uuid
          end

          iter.return(acc)
        end

        done = ->(errors) { responder.succeed(format_error_message(errors)) }

        EM::Iterator.new(target).inject([], work, done)
      end

      private

      def format_error_message(errors)
        errors = errors.compact
        case errors.size
        when 0
          ''
        when 1
          "Agent does not exist: #{errors.first}"
        else
          "Agents do not exist: #{errors.join(", ")}"
        end
      end

      def options_spec
        banner "Kill an agent/agents.", "<uuid[s]>"
      end
    end
  end
end
