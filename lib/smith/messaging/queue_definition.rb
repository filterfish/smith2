# -*- encoding: utf-8 -*-

module Smith
  class QueueDefinition

    attr_reader :name, :options

    def initialize(name, options)
      @name = name
      @options = options
    end

    # to_a is defined to make the splat operator work.
    def to_a()
      return @name, @options
    end
  end
end
