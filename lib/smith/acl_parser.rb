# -*- encoding: utf-8 -*-

require 'set'
require 'sexp_processor'
require 'ruby_parser'
require 'optparse'
require 'timeout'

module Smith
  class ACLParser < SexpProcessor

    def initialize
      super()
      @class_stack         = []
      self.auto_shift_type = true
      self.reset
    end

    def go(ruby)
      @parser = RubyParser.new
      process(@parser.process(ruby))
    end

    # Adds name to the class stack, for the duration of the block
    def in_class(name)
      @class_stack.unshift(name)
      yield
      @class_stack.shift
    end

    # Returns the first class in the list, or :main
    def class_name
      if @class_stack.any?
        @class_stack.reverse
      else
        :main
      end
    end

    # Process each element of #exp in turn.
    def process_until_empty(exp)
      process(exp.shift) until exp.empty?
    end

    def fully_qualified_classes
      @classes.delete(:main)
      @classes.inject([]) do |a, class_method|
        a.tap do |acc|
          acc << class_method
        end
      end
    end

    # Reset @classes data
    def reset
      @classes = Set.new
    end

    # Process Class method
    def process_class(exp)
      in_class(exp.shift) do
        process_until_empty exp
        @classes << class_name
      end
      s()
    end

    def process_module(exp)
      in_class exp.shift do
        process_until_empty exp
      end
      s()
    end
  end
end
