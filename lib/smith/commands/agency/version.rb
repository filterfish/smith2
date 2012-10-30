# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Version < CommandBase
      def execute
        version do |v|
          responder.succeed(v)
        end
      end

      def version(&blk)
        if options[:git]
          # EM.system doesn't do any shell expansion so do it ourselves.
          EM.system("sh -c 'git describe 2> /dev/null'") do |output,status|
            blk.call((status.exitstatus == 0) ? output.strip : 'The agency is not running in a git repo.')
          end
        else
          blk.call(Smith::VERSION)
        end
      end

      private

      def options_spec
        banner "Display the agency version."

        opt    :git, "run git describe, assuming git is installed", :short => :g
      end
    end
  end
end
