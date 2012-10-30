# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Commands < CommandBase
      def execute
        commands = (target.empty?) ? Command.commands : target
        responder.succeed(format(commands))
      end

      def format(commands)
        if options[:long]
          c = instantiate_commands(commands)
          if options[:type]
            c.map { |k,v| sprintf("%1$*4$s - %2$s [%3$s]", k, remove_new_lines(v), Command.command_type(k), -(max_length(c) + 1)) }.join("\n")
          else
            c.map { |k,v| sprintf("%1$*3$s - %2$s", k, remove_new_lines(v), -(max_length(c) + 1)) }.join("\n")
          end
        else
          if options[:type]
            instantiate_commands(commands).map { |k,v| sprintf("%s - %s", k, Command.command_type(k)) }
          else
            commands.sort.join("\n")
          end
        end
      end

      private

      def instantiate_commands(commands)
        commands.sort.inject({}) do |a, command|
          a.tap do |acc|
            Command.load_command(command)
            clazz = Command.instantiate(command)
            acc[command] = clazz.banner
          end
        end
      end

      def remove_new_lines(s)
        s.split("\n").map(&:strip).select {|a| !a.empty? }.join(" ")
      end

      def options_spec
        banner "List available commands.\n\n  If a command/commands is given only that command will be shown."

        opt    :long, "include the short usage message", :short => :l
        opt    :type, "show whether the command is a smithctl command or an agency command ", :short => :t
      end

      def max_length(banners_hash)
        banners_hash.keys.map(&:length).max
      end
    end
  end
end
