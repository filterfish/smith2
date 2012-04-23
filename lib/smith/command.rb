# -*- encoding: utf-8 -*-

require 'trollop'

module Smith
  class Command
    class UnknownCommandError < RuntimeError; end

    include Logger

    # Load and run the command specified. This method takes:
    # +target+ which is either a list of agents or the agency
    # +vars+ variables to be passed in to the command. This takes the
    # form of a hash and accessor methods are generated named after the
    # key of the hash.

    def self.run(command, args, vars)
      # Change _ to - underscores look so ugly as a command name.
      command = command.gsub(/-/, '_')
      logger.debug { "Agency command: #{command}#{(args.empty?) ? '' : " #{args.join(', ')}"}." }

      load_command(command)

      clazz = Commands.const_get(Extlib::Inflection.camelize(command)).new

      begin
        options, target = parse_options(clazz, args)

        vars.merge(:options => options, :target => target).each do |k,v|
          clazz.instance_eval <<-EOM, __FILE__, __LINE__ + 1
            instance_variable_set(:"@#{k}", v)
            def #{k}=(z); @#{k} = z; end
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

    def self.banner_template(clazz)
      return <<EOS

  %s

  Usage:
    smithctl #{clazz.class.to_s.split('::').last.downcase} Options

Options are:
EOS
    end

    private

    # Determine whether the command is an agency or smithctl command and load
    # accordingly.
    def self.load_command(cmd)
      require command_path(cmd)
    end

    # Check to see if the command is an agency or smithctl command.
    def self.agency?
      Smith.constants.include?(:Agency)
    end

    # Return the full path of the ruby class.
    def self.command_path(command)
      send("#{command_type(command)}_path").join(command)
    end

    # What type of command is it?
    def self.command_type(command)
      case
      when agency_command?(command)
        :agency
      when smithctl_command?(command)
        :smithctl
      else
        raise UnknownCommandError, "Unknown command: #{command}"
      end
    end

    # Is the command an agency command?
    def self.agency_command?(cmd)
     agency_path.join(cmd).sub_ext('.rb').exist?
    end

    # Is the command a smithctl command?
    def self.smithctl_command?(cmd)
      smithctl_path.join(cmd).sub_ext('.rb').exist?
    end

    # Return the agency command base path.
    def self.agency_path
      base_path.join('agency')
    end

    # Return the smithctl command base path.
    def self.smithctl_path
      base_path.join('smithctl')
    end

    # Return the command base path.
    def self.base_path
      @c64a6f4f ||= Smith.root_path.join('lib').join("smith").join('commands')
    end

    # Uses the options_parser method in the specific command class to process
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
