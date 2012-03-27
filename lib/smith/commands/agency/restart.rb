# -*- encoding: utf-8 -*-

require_relative 'common'

# This is a meta-command. It doesn't implement anything it simply sends
# messages to one or many existing commands to do the work.

module Smith
  module Commands
    class Restart < Command

      include Common

      def execute
        Messaging::Sender.new('agency.control', :auto_delete => true, :durable => false, :strict => true).ready do |sender|
          payload = ACL::Payload.new(:agency_command).content(:command => 'stop', :args => target)

          sender.publish_and_receive(payload) do |r|
            payload = ACL::Payload.new(:agency_command).content(:command => 'start', :args => target)
            EM.add_timer(0.5) do
              sender.publish_and_receive(payload) do |r|
                responder.value
              end
            end
          end
        end
      end


      def options_parser
        command = self.class.to_s.split(/::/).last.downcase
        Trollop::Parser.new do
          banner  Command.banner(command)
          opt     :group,     "Start everything in the specified group", :type => :string, :short => :g
        end
      end
    end
  end
end
