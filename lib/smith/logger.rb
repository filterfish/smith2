require 'logging'

module Smith
  module Mixin
    module Logger

      @logger = nil

      def logger(log_config=nil, name=nil)
        init(log_config, name)
      end

      def init(log_config=nil, name=nil)
        if @logger.nil?
          @logger = if log_config
                      ::Logging.configure(log_config)
                      ::Logging::Logger[name]
                    else
                      ::Logging.logger(STDOUT)
                    end
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
