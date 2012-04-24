# -*- encoding: utf-8 -*-

require 'trollop'

module Smith
  class CommandBase
    class UnkownCommandError < RuntimeError; end

    attr_reader :options, :target

    include Logger

    def initialize
      @parser = Trollop::Parser.new
      if self.respond_to?(:options_spec)
        options_spec
      else
        raise RuntimeError, "You should really add an options_spec method with at least a banner method call."
      end
    end

    def parse_options(args)
      @options = @parser.parse(args)
      @target = args
    end

    def format_help(opts={})
      StringIO.new.tap do |help|
        help.puts opts[:prefix] if opts[:prefix]
        @parser.educate(help)
        help.rewind
      end.read
    end

    protected

    def opt(*opt_spec)
      @parser.opt(*opt_spec)
    end

    def banner(banner, opts={})
      if opts[:no_template]
        @parser.banner(banner)
      else
        @parser.banner(banner_template(banner))
      end
    end

    private

    def banner_template(text)
      return <<-EOS

  #{text}

  Usage:
    smithctl #{self.class.to_s.split('::').last.downcase} OPTIONS

OPTIONS are:
      EOS
    end
  end
end
