module Smith
  module Logger

    def self.included(base)
      base.class_eval do
        include Methods
        extend Methods
      end
    end


    module Methods
      protected

      @@__pattern = "%5l - %30c:%-3L - %m\n"
      @@__level = :debug
      @@__trace = true
      @@__appender_type = Logging::Appenders::Stdout
      @@__name = 'smith'

      def log_level(level=nil)
        if level
          @@__level = level
          @reload = true
        end
        Logging.logger.root.level = @@__level
      end

      def log_appender(opts={})
        if @appender.nil? || !opts.empty?
          @@__name = opts[:name] if opts[:name]
          @@__appender_type = opts[:class] if opts[:class]
          @appender = @@__appender_type.send(:new, @@__name, :layout => log_pattern)
          @reload = true
        end
        Logging.logger.root.appenders = @appender
      end

      def log_pattern(pattern=nil)
        if pattern
          @@__pattern = pattern
          @reload = true
        end
        Logging.layouts.pattern({:pattern => @@__pattern, :date_pattern => "%H:%M:%S"})
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
