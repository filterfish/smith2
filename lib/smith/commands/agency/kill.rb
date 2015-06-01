# -*- encoding: utf-8 -*-
require_relative '../common'

module Smith
  module Commands
    class Kill < CommandBase

      include Common

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

        EM::Iterator.new(agents_to_kill).inject([], work, done)
      end

      private

      def agents_to_kill
        if options[:group]
          agents.find_by_name(agent_group(options[:group])).map(&:uuid)
        else
          target
        end
      end

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

        opt    :group,  "kill agents in this group", :type => :string, :short => :g
      end
    end
  end
end
