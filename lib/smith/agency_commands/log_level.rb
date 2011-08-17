#encoding: utf-8

module Smith
  module AgencyCommands
    class LogLevel < AgencyCommand
      def execute(target)
        level = target.shift

        if level.nil?
          logger.warn("No log level. You must specify a log level and a target")
        else
          case target.first
          when 'all'
            agents.state(:running).each do |agent|
              send_agent_control_message(agent, :command => :log_level, :args => level)
            end
          when 'agency'
            begin
              logger.info("Setting agency log level to: #{level}")
              log_level(level)
            rescue ArgumentError
              logger.error("Incorrect log level: #{level}")
            end
          when nil
            logger.warn("No target. You must specify one of the following: agency, all or a list of agents")
          else
            target.each do |agent|
              if agents[agent].running?
                send_agent_control_message(agents[agent], :command => :log_level, :args => level)
              end
            end
          end
        end
      end

      private

      def send_agent_control_message(agent, message)
        Smith::Messaging.new(agent.control_queue_name).send_message(message)
      end
    end
  end
end
