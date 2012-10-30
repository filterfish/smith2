# -*- encoding: utf-8 -*-

require 'extlib/string'

module Smith
  module Commands
    class Acls < CommandBase
      def execute
        responder.succeed(acl)
      end

      def acl
        if options[:show]
          if target.empty?
            "You must supply an ACL file name."
          else
            target.map do |acl|
              acls = Smith.acl_path.inject([]) do |a,path|
                a.tap do |acc|
                  acl_file = path.join("#{acl.snake_case}.proto")
                  if acl_file.exist?
                    acc << acl_file
                  end
                end
              end

              case acls.length
              when 0
                "ACL file does not exist."
              when 1
                if target.length == 1
                  "\n#{indent_acl(acls.first.read)}\n"
                else
                  "\n#{acl} ->\n#{indent_acl(acls.first.read)}"
                end
              else
                "There are multiple ACLs with the name: #{target}"
              end
            end.join("\n")
          end
        else
          join_string = (options[:long]) ? "\n" : " "
          Pathname.glob(Smith.acl_path.map {|p| "#{p}#{File::SEPARATOR}*"}).map do |p|
            p.basename(".proto")
          end.sort.join(join_string)
        end
      end

      private

      def indent_acl(acl)
        acl.split("\n").map { |l| l.sub(/^/, "  ") }.join("\n")
      end

      def options_spec
        banner "List and display acl files."

        opt    :long, "format the listing", :short => :l
        opt    :show, "show the contents of the acl file", :short => :s
      end
    end
  end
end
