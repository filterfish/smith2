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

      @@__pattern = Smith::Config.get.logging.default_pattern
      @@__date_pattern = Smith::Config.get.logging.default_date_pattern
      @@__level = Smith::Config.get.logging.level
      @@__trace = Smith::Config.get.logging.trace
      @@__appender_type = Logging::Appenders.const_get(Smith::Config.get.logging.appender.to_s.to_sym)
      @@__appender_filename = Smith::Config.get.logging.filename
      @@__name = 'smith'

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
          @@__appender_type = opts[:class] if opts[:class]
          @appender = @@__appender_type.send(:new, @@__name, :filename => @@__appender_filename, :layout => log_pattern)
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
