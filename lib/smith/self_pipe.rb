module Smith
  class SelfPipe

    include Smith::Logger

    def initialize(agent)
      @agent = agent

      @signal_handlers = Hash.new { |h,k| h[k] = Array.new }
      @signal_handler_queue = []
      @signal_handler_pipe_reader, @signal_handler_pipe_writer = IO.pipe

      setup_signal_handlers
    end

    # Adds a signal handler proc to the list of signal_handlers. When
    # a signal is received all signal handlers are called in reverse order.
    #
    # @param signal [Integer] the signal number.
    # @param position [Symbol] [:first|:last] where on the signal handler stack
    #        to put the handler proc.
    #
    # @see Signal.list for a full list of available signals on a system.
    def install_signal_handler(signal, position=:end, &blk)
      raise ArgumentError, "Unknown position: #{position}" if ![:beginning, :end].include?(position)
      logger.debug { "Installing signal handler for #{signal}" }

      @signal_handlers[signal].insert((position == :beginning) ? 0 : -1, blk)

      Signal.trap(signal) {
        @signal_handler_pipe_writer.write_nonblock('.')
        @signal_handler_queue << signal
      }
    end

    # Set up the mechanics required to implement the self pipe trick.
    def setup_signal_handlers
      # The Module declaration here will only close over local variables so we
      # need to assign self to a local variable to get access to the agent itself.
      clazz = self

      EM.attach(@signal_handler_pipe_reader, Module.new {
        define_method :receive_data do |_|

          handlers = clazz.instance_variable_get(:@signal_handlers)
          queue = clazz.instance_variable_get(:@signal_handler_queue)
          signal = queue.pop

          clazz.send(:logger).debug { "Running signal handlers for: #{signal}" }
          handlers[signal].each { |handler| handler.call(signal) }
        end
      })
    end
  end
end
