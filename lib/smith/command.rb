# -*- encoding: utf-8 -*-

require 'trollop'
require 'smith/command_base'

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
      load_command(command)

      clazz = Commands.const_get(Inflecto.camelize(command)).new

      begin
        clazz.parse_options(args)

        vars.each do |k,v|
          clazz.instance_eval <<-EOM, __FILE__, __LINE__ + 1
            instance_variable_set(:"@#{k}", v)
            def #{k}=(z); @#{k} = z; end
            def #{k}; @#{k}; end
          EOM
        end

        clazz.execute

      rescue Trollop::CommandlineError => e
        vars[:responder].succeed(clazz.format_help(:prefix => "Error: #{e.message}.\n"))
      rescue Trollop::HelpNeeded
        vars[:responder].succeed(clazz.format_help)
      end
    end

    # Determine whether the command is an agency or smithctl command and load
    # accordingly.
    def self.load_command(command)
      require command_path(command)
    end

    def self.instantiate(command)
      Commands.const_get(Inflecto.camelize(command)).new
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

    def self.commands(type=:all)
      types = case type
      when :all
        ['agency', 'smithctl']
      when :agency
        types = ['agency']
      when :smithctl
        types = ['smithctl']
      else
        raise ArgumentError, "Unknown command type"
      end

      types.map do |type|
        Pathname.glob(base_path.join(type).join("**/*.rb"))
      end.flatten.map {|p| to_command_name(p) }
    end

    # Check to see if the command is an agency or smithctl command.
    def self.agency?
      Smith.constants.include?(:Agency)
    end

    private

    # Return the full path of the ruby class.
    def self.command_path(command)
      send("#{command_type(command)}_path").join(command)
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

    def self.to_command_name(path)
      path.basename(".rb").to_s
    end

    # Return the command base path.
    def self.base_path
      @c64a6f4f ||= Smith.root_path.join('lib').join("smith").join('commands')
    end
  end
end
