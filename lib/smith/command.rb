# -*- encoding: utf-8 -*-

require 'trollop'

module Smith
  class Command
    class UnkownCommandError < RuntimeError; end

    include Logger

    # Load and run the command specified. This method takes:
    # +target+ which is either a list of agents or the agency
    # +vars+ variables to be passed in to the command. This
    # takes the form of a hash and accessor methods are generated
    # named after the key of the hash.
    def self.run(command, args, vars)
      target ||= []
      # Change _ to - underscores look so ugly as a command name.
      command.gsub!(/-/, '_')
      logger.debug("Agency command: #{command}#{(target.empty?) ? '' : " #{target.join(', ')}"}.")

      load_command(command)

      clazz = Commands.const_get(Extlib::Inflection.camelize(command)).new

      begin
        options, target = parse_options(clazz, args)

        vars.merge(:options => options, :target => target).each do |k,v|
          clazz.instance_eval <<-EOM, __FILE__, __LINE__ + 1
            instance_variable_set(:"@#{k}", v)
            def #{k}; @#{k}; end
          EOM
        end

        clazz.execute

      rescue Trollop::CommandlineError => e
        vars[:responder].value(parser_help(clazz, :prefix => "Error: #{e.message}.\n"))
      rescue Trollop::HelpNeeded
        vars[:responder].value(parser_help(clazz))
      end
    end

    # Banner callback. This is called when the parser is called.
    # I'm sure there is a better way of doing this.
    def self.banner(command)
      "smithctl #{command} OPTIONS [Agents]"
    end

    private

    # Load the command from the lib/smith/commands directory.
    def self.load_command(cmd)
      cmd_path = Smith.root_path.join('lib').join("smith").join('commands').join(cmd.to_s)
      if cmd_path.sub_ext('.rb').exist?
        require cmd_path
      else
        raise UnkownCommandError, "Command class does not exist: #{cmd}"
      end
    end

    # Uses the options_parser method in the specific command class to procees
    # any options associated with that command. If no options_parser method
    # exits then an empty Array is returned. Any members of the args array
    # that are not parsed by the options parser are return as the target, i.e.
    # the agent(s) that the command is to operate on.
    def self.parse_options(clazz, args)
      if clazz.respond_to?(:options_parser)
        [clazz.options_parser.parse(args), args]
      else
        [{}, args]
      end
    end

    def self.parser_help(clazz, opts={})
      StringIO.new.tap do |help|
        help.puts opts[:prefix] if opts[:prefix]
        clazz.options_parser.educate(help)
        help.rewind
      end.read
    end
  end
end
