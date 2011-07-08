require 'logging'

module Smith
  module Mixin
    module Logger

      @logger = nil

      def logger
        init
      end

      def init
        if @logger.nil?
          pattern_spec = {:pattern => "%.1l, [%d] -- %c:%L %m\n", :date_pattern => "%H:%M:%S"}
          appender = Logging.appenders.stdout(:layout => Logging.layouts.pattern(pattern_spec))

          Logging.logger.root.appenders = appender
          Logging.logger.root.level = :debug
          @logger = Logging.logger[Smith::Agent]
          @logger.trace = true
        end
        @logger
      end

      def method_missing(method_symbol, *args)
        logger.send(method_symbol, *args)
      end
    end
  end

  class Logger
    extend Mixin::Logger
  end
end
