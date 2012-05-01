# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Version < CommandBase
      def execute
        # FIXME Puts some error handling for when the agency isn't running in a git repo.
        if options[:git]
          EM.system('git describe') do |output,status|
            responder.value do
              if status.exitstatus == 0
                output.strip
              else
                'The agency is not running in a git repo.'
              end
            end
          end
        else
          responder.value(Smith::VERSION)
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
