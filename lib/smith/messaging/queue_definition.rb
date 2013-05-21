# -*- encoding: utf-8 -*-

module Smith
  class QueueDefinition

    attr_reader :options

    def initialize(name, options)
      @normalised_queue = "#{Smith.config.smith.namespace}.#{name}"
      @denormalised_queue = "#{name}"
      @options = options
    end

    def denormalise
      @denormalised_queue
    end

    def name
      @normalised_queue
    end

    def normalise
      @normalised_queue
    end

    # to_a is defined to make the splat operator work.
    def to_a
      return @normalised_queue, @options
    end

    def to_s
      "<#{self.class}: #{@denormalised_queue}, #{@options.inspect}>"
    end
  end
end
