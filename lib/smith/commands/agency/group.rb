require_relative '../common'

module Smith
  module Commands
    class Group < CommandBase

      include Common

      def execute
        group do |value|
          responder.succeed(value)
        end
      end

      # Returns the agents in a group.
      def group(&blk)
        begin
          blk.call(agent_group(target.first).join(' '))
        rescue RuntimeError => e
          blk.call(e.message)
        end
      end

      def options_spec
        banner "Lists the agents in a group.", "<group>"

        opt    :one_column, "the number of times to send the message", :short => :s
      end
    end
  end
end
