# -*- encoding: utf-8 -*-

require 'smith/messaging/queue'

module Smith
  module Commands
    class Status < CommandBase
      def execute
        status do |s|
          responder.succeed((s) ? "Agency running" : "Agency not running")
        end
      end

      def status(&blk)
        Messaging::Queue.number_of_consumers(QueueDefinitions::Agency_control.call) do |consumers_count|
          blk.call(consumers_count > 0)
        end
      end

      private

      def options_spec
        banner "Shows the status of the agency — ONLY WORKS LOCALLY"
      end
    end
  end
end
