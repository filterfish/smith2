# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Logger < Command
      def execute
        responder.value do
          if options[:level].nil?
            "No log level. You must specify a log level and a target"
          else
            case target.first
            when 'all'
              agents.state(:running).each do |agent|
                send_agent_control_message(agent, :command => 'log_level', :options => options[:level])
              end
              nil
            when 'agency'
              begin
                logger.info("Setting agency log level to: #{options[:level]}")
                log_level(options[:level])
                nil
              rescue ArgumentError
                logger.error("Incorrect log level: #{options[:level]}")
                nil
              end
            when nil
              "No target. You must specify one of the following: 'agency', 'all' or a list of agents"
            else
              target.each do |agent|
                if agents[agent].running?
                  send_agent_control_message(agents[agent], :command => 'log_level', :options => options[:level])
                end
              end
              nil
            end
          end
        end
      end

      def options_parser
        Trollop::Parser.new do
          banner  Command.banner('logger')
          opt     :level,               "the log level you want to set", :type => :string, :short => :l
          opt     :trace,               "turn trace on or off", :type => :boolean, :short => :t
        end
      end

      private

      def send_agent_control_message(agent, message)
        Messaging::Sender.new(agent.control_queue_name).ready do |sender|
          sender.publish(ACL::Payload.new(:agent_command).content(message))
        end
      end
    end
  end
end
