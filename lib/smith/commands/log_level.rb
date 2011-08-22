#encoding: utf-8

module Smith
  module Commands
    class LogLevel < Command
      def execute(target)
        level = target.shift

        if level.nil?
          #logger.warn("No log level. You must specify a log level and a target")
          "No log level. You must specify a log level and a target")
        else
          case target.first
          when 'all'
            agents.state(:running).each do |agent|
              send_agent_control_message(agent, :command => :log_level, :args => level)
            end
            nil
          when 'agency'
            begin
              logger.info("Setting agency log level to: #{level}")
              log_level(level)
              nil
            rescue ArgumentError
              logger.error("Incorrect log level: #{level}")
              nil
            end
          when nil
            #logger.warn("No target. You must specify one of the following: agency, all or a list of agents")
            "No target. You must specify one of the following: 'agency', 'all' or a list of agents"
          else
            target.each do |agent|
              if agents[agent].running?
                send_agent_control_message(agents[agent], :command => :log_level, :args => level)
              end
            end
            nil
          end
        end
      end

      private

      def send_agent_control_message(agent, message)
        Messaging::Sender.new(agent.control_queue_name).publish(message)
      end
    end
  end
end
