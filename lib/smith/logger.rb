require 'logging'

# TODO learn more about module programming and do this properly.  It works
# ok at the moment but I don't think it's done well and somethings don't
# work, for example the trace level can only be changed once. If you start
# out with info level and change it to dubug the trace level will still
# be false and you won't get line numbers even though it is spceified in
# the layout pattern.

module Smith
  module Logger

    protected

    @@__pattern = "[%d] %5l - %30c:%-3L - %m\n"
    @@__level = :debug
    @@__trace = true

    def self.level(level)
      @@__level = level
      Logging.logger.root.level = level
      @@__trace = (@@__level == :debug) ? true : false
    end

    def self.pattern(pattern)
      @@__pattern = pattern
      pattern_spec = {:pattern => @@__pattern, :date_pattern => "%H:%M:%S"}
      appender = Logging.appenders.stdout(:layout => Logging.layouts.pattern(pattern_spec))
      Logging.logger.root.appenders = appender
      @logger.trace = @@__trace if @logger
    end

    def logger
      if @logger.nil?
        Logger.pattern(@@__pattern)
        Logger.level(@@__level)
        @logger = Logging.logger[self]
        @logger.trace = @@__trace
      end
      @logger
    end
  end
end
