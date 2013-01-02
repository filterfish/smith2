# -*- encoding: utf-8 -*-

require_relative '../common'

# This is a meta-command. It doesn't implement anything it simply sends
# messages to one or many existing commands to do the work.

module Smith
  module Commands
    class Restart < CommandBase

      include Common

      def execute
        Messaging::Sender.new(QueueDefinitions::Agency_control) do |sender|
          @sender = sender

          # agent is a method and as such I cannot pass it into the block.
          # This just assigns it to a local method making it all work.

          lagents = agents
          # lagents.each do |agent_name|
          worker = ->(agent_name, iter) do
            lagents[agent_name].stop
            lagents[agent_name].add_callback(:acknowledge_stop) do
              lagents.invalidate(agent_name)
              lagents[agent_name].start
            end
            iter.next
          end

          done = -> { responder.succeed('') }

          EM::Iterator.new(target).each(worker, done)
        end
      end

      private

      def options_spec
        banner "Restart an agent/agents."

        opt    :group,     "Start everything in the specified group", :type => :string, :short => :g
      end
    end
  end
end
