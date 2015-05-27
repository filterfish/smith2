# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Logger < CommandBase
      def execute
        responder.succeed((_logger))
      end

      def _logger(&blk)
        error_messages = []
        if options[:level].nil?
          error_messages << "No log level. You must specify a log level and a target"
        else
          case target.first
          when 'all'
            agents.state(:running).each do |agent|
              error_messages << set_log_level(agent.uuid)
            end
            ''
          when 'agency'
            begin
              logger.info { "Setting agency log level to: #{options[:level]}" }
              log_level(options[:level])
            rescue ArgumentError
              m = "Incorrect log level: #{options[:level]}"
              logger.error { m }
              error_messages << m
            end
            ''
          when nil
            error_messages << "No target. You must specify one of the following: 'agency', 'all' or a list of agents"
          else
            target.each do |uuid|
              error_messages << set_log_level(uuid)
            end
          end
        end
        error_messages.compact.join(", ")
      end

      private

      def set_log_level(uuid)
        agent = agents[uuid]
        if agent && agent.running?
          send_agent_control_message(agent, :command => 'log_level', :options => [options[:level]])
          nil
        else
          "Agent does not exist: #{uuid}"
        end
      end

      def send_agent_control_message(agent, message)
        Messaging::Sender.new(agent.control_queue_def) do |sender|
          sender.publish(ACL::AgentCommand.new(message))
        end
      end

      def options_spec
        banner "Change the log and trace level of the agents or the agency.", "<uuid[s]>"

        opt    :level, "the log level you want to set", :type => :string, :short => :l
        opt    :trace, "turn trace on or off", :type => :boolean, :short => :t
      end
    end
  end
end
