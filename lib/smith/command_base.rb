# -*- encoding: utf-8 -*-

require 'trollop'

module Smith
  class CommandBase
    class UnkownCommandError < RuntimeError; end

    attr_reader :options, :target

    include Logger

    def initialize
      @parser = Trollop::Parser.new
      options_spec
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

    def banner(banner=nil, additional_text=nil, opts={})
      if banner.nil?
        @banner
      else
        @banner = banner
        @parser.banner((opts[:no_template]) ? banner : banner_template(banner, additional_text))
      end
    end

    protected

    def opt(*opt_spec)
      @parser.opt(*opt_spec)
    end

    def conflicts(*syms)
      @parser.conflicts(*syms)
    end

    def depends(*syms)
      @parser.depends(*syms)
    end

    def options_spec
      banner "You should really set a proper banner notice for this command."
    end

    private

    def banner_template(text, additional_text)
      return %(
  #{text}

  Usage:
    smithctl #{self.class.to_s.split('::').last.downcase} [Options]#{(additional_text) ? " #{additional_text}" : ''}

[Options] are:
    )
    end
  end
end
