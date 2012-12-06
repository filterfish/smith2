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

      @@__name = 'smith'
      @@__pattern = Smith::Config.get.logging.default_pattern
      @@__date_pattern = Smith::Config.get.logging.default_date_pattern
      @@__level = Smith::Config.get.logging.level
      @@__trace = Smith::Config.get.logging.trace
      @@__appender = Smith::Config.get.logging.appender.to_hash.clone
      @@__appender[:type] = Logging::Appenders.const_get(Extlib::Inflection.camelize(Smith::Config.get.logging.appender.type))

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

      def log_appender(opts={})
        if @appender.nil? || !opts.empty?
          @@__name = opts[:name] if opts[:name]
          @appender = @@__appender[:type].send(:new, @@__name, @@__appender.merge(:layout => log_pattern))
          @reload = true
        end
        Logging.logger.root.appenders = @appender
      end

      def log_pattern(*pattern)
        case pattern.size
        when 1
          @@__pattern = pattern.shift
          @reload = true
        when 2
          @@__pattern = pattern.shift
          @@__date_pattern = pattern.shift
          @reload = true
        end

        Logging.layouts.pattern({:pattern => @@__pattern, :date_pattern => @@__date_pattern})
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
        self.log_pattern
        self.log_appender
        self.log_level
        @reload = true
      end

      def __reload
        @logger = Logging.logger[self || 'main']
        @logger.trace = @@__trace
        @reload = false
      end
    end
  end
end
