require 'pp'
require 'state_machine'
require 'dm-core'
require 'dm-yaml-adapter'

module Smith
  class AgentProcess

    include DataMapper::Resource
    include Extlib

    property :id,               Serial
    property :name,             String, :required => true
    property :state,            String, :required => true
    property :pid,              Integer
    property :name,             String
    property :started_at,       Time
    property :last_keep_alive,  Time
    property :restart,          Boolean
    property :singleton,        Boolean

    state_machine :initial => :null do

      before_transition do |transition|
        logger.debug("Tranisiton [#{name}]: :#{transition.from} -> :#{transition.to}")
      end

      after_failure do |transition|
        logger.warn("Illegal state change [#{name}]: :#{transition.from} -> :#{transition.to}")
      end

      after_transition :on => :start, :do => :do_start
      after_transition :on => :acknowledge_start, :do => :do_acknowledge_start
      after_transition :on => :stop, :do => :do_stop
      after_transition :on => :acknowledge_stop, :do => :do_acknowledge_stop

      event :instantiate do
        transition [:null] => :stopped
      end

      event :start do
        transition [:null, :stopped, :dead] => :starting
      end

      event :acknowledge_start do
        transition [:starting] => :running
      end

      event :stop do
        transition [:running] => :stopping
      end

      event :acknowledge_stop do
        transition [:stopping] => :stopped
      end

      event :no_process_running do
        transition [:starting, :running, :stopping] => :dead
      end

      event :not_responding do
        transition [:starting, :acknowledge_start, :acknowledge_stop, :running, :stopping] => :unkown
      end
    end

    private

    attr_accessor :agent_name, :logger

    def initialize(args, opts={})
      @logger = Logging.logger(STDOUT)
      @base_path = '/home/rgh/dev/ruby/smith2/agents'
      #@base_path = opts[:agents_path] or raise ArgumentError, "no agents path supplied"
      @bootstraper = File.expand_path(File.join(File.dirname(__FILE__), 'bootstrap.rb'))
      @logging_path = opts[:logging] || ''

      super(args)
    end

    def do_start
      start_agent
    end

    def do_stop
      stop_agent
    end

    def do_acknowledge_start
    end

    def do_acknowledge_stop
    end

    def start_agent
      self.pid = fork do
        # Detach from the controlling terminal
        unless sess_id = Process.setsid
          raise 'Cannot detach from controlling terminal'
        end

        # Close all file descriptors apart from stdin, stdout, stderr
        ObjectSpace.each_object(IO) do |io|
          unless [STDIN, STDOUT, STDERR].include?(io)
            io.close rescue nil
          end
        end

        # Sort out the remaining file descriptors. Don't do anything with
        # stdout (and by extension stderr) as want the agency to manage it.
        STDIN.reopen("/dev/null")
        STDERR.reopen("/dev/null")
        #STDERR.reopen(STDOUT)

        exec('ruby', @bootstraper, @base_path, name, @logging_path)
      end

      # We don't want any zombies.
      Process.detach(pid)
    end

    def stop_agent
      Smith::Messaging.new("agent.#{name.snake_case}").send_message("stop")
    end
  end
end
