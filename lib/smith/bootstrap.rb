# -*- encoding: utf-8 -*-
#
# This should never be run directly it should only be
# ever run by the agency.

$: << File.dirname(__FILE__) + '/..'

require 'smith'

module Smith
  class AgentBootstrap

    attr_reader :agent

    include Logger

    def initialize(path, agent_name)
      # FIXME
      # This doesn't do what I think it should. If an exception is
      # thrown in setup_control_queue, for example, it just kills
      # the agent without it actually raising the exception.
      Thread.abort_on_exception = true
      @agent_name = agent_name
      @agent_filename = File.expand_path(File.join(path, "#{agent_name.snake_case}.rb"))
    end

    def signal_handlers
      logger.debug("Installing default signal handlers")
      %w{TERM INT QUIT}.each do |sig|
        @agent.install_signal_handler(sig) do |sig|
          logger.error("Agent received: signal #{sig}: #{agent.name}")
          terminate!
        end
      end
    end

    def load_agent
      load @agent_filename
      @agent = Kernel.const_get(@agent_name).new
    end

    def start!
      write_pid_file
      @agent.run
    end

    # Exceptional shutdown of the agent. Note. Whenever this is
    # called it almost certain that the reactor is not going to
    # be running. So it must be restarted and then shutdown again
    # See the note at the in main.
    def terminate!(exception=nil)
      logger.error("Terminating: #{@agent_name}.")
      if exception
        logger.error(exception.message)
        logger.debug(exception)
      end

      if Smith.running?
        send_dead_message
        unlink_pid_file
        Smith.stop
      else
        logger.debug("Reconnecting to AMQP Broker.")
        Smith.start do
          send_dead_message
          unlink_pid_file
          Smith.stop
        end
      end
    end

    # Clean shutdown of the agent.
    def shutdown
      logger.debug("Agent stopped: #{@agent_name}")
      unlink_pid_file
      Smith.stop if Smith.running?
    end

    private

    def write_pid_file
      @pid = Daemons::PidFile.new(Daemons::Pid.dir(:normal, Dir::tmpdir, nil), ".rubymas-#{@agent_name.snake_case}", true)
      @pid.pid = Process.pid
    end

    def send_dead_message
      logger.debug("Sending dead message to agency: #{@agent_name}")
      Messaging::Sender.new('agent.lifecycle').publish(:state => :dead, :data => {:name => @agent_name})
    end

    def unlink_pid_file
      if @pid && @pid.exist?
        logger.debug("Cleaning up pid file: #{@pid.filename}")
      end
    end
  end
end

path = ARGV[0]
agent_name = ARGV[1]

exit 1 if agent_name.nil? || path.nil?

# Set the running instance name to the name of the agent.
$0 = "#{agent_name}"

bootstrapper = Smith::AgentBootstrap.new(path, agent_name)

# I've tried putting the exception handling in the main reactor loog
# but it doesn't do anything. I know theres a resaon for this but I
# don't what it is at the moment. Just beware that whenever there
# is an exception the recator is not going going to be running.
begin
  Smith.start do
    bootstrapper.load_agent
    bootstrapper.signal_handlers
    bootstrapper.start!
  end
  bootstrapper.shutdown
rescue Exception => e
  bootstrapper.terminate!(e)
end
