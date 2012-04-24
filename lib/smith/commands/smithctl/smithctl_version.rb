# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class SmithctlVersion < CommandBase
      def execute
        version_file = Smith.root_path.join('VERSION')

        if options[:git] || !version_file.exist?
          responder.value("#{(`git describe` rescue '').strip}")
        else
          responder.value(version_file.read.strip)
        end
      end

      def options_spec
        banner "Displays the smithctl version."

        opt    :git, "run git describe, assuming git is installed", :short => :g
      end
    end
  end
end
