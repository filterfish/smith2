# -*- encoding: utf-8 -*-
module Smith
  module Logger

    def self.included(base)

      if !Logging.const_defined?(:MAX_LEVEL_LENGTH)
        Logging.init([:verbose, :debug, :info, :warn, :error, :fatal])
      end

      base.class_eval do
        include Methods
        extend Methods
      end
    end

    module Methods
      protected

      @@__level = Smith::Config.get.logging.level
      @@__trace = Smith::Config.get.logging.trace

      @@appender = nil

      def log_level(level=nil)
        if level
          if Logging::LEVELS[level.to_s]
            @@__level = level
            @reload = true
          else
            raise ArgumentError, "Unknown level: #{level}"
          end
        end
        Logging.logger.root.level = @@__level
      end

      def log_appender
        unless @@appender
          appender_type = Extlib::Inflection.camelize(Config.get.logging.appender.type)
          pattern_opts = {
            :pattern => Config.get.logging.default_pattern,
            :date_pattern => Config.get.logging.default_date_pattern}

          appender_opts = Config.get.logging.appender.clone.merge(:layout => Logging.layouts.pattern(pattern_opts))

          @@appender = Logging::Appenders.const_get(appender_type).new('smith', appender_opts)
        end

        Logging.logger.root.appenders = @@appender
      end

      def log_trace(trace)
        @@__trace = trace
        @reload = true
      end

      def logger
        __setup if @logger.nil?
        __reload if @reload
        @logger
      end

      private

      def __setup
        self.log_appender
        self.log_level
        @reload = true
      end

      def __reload
        @logger = Logging.logger[self.class.to_s || 'main']
        @logger.trace = @@__trace
        @reload = false
      end
    end
  end
end
